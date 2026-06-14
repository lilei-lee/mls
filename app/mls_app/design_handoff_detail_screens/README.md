# 交接包：房源详情 / 留痕时间线 / 消息通知（3 个推入式详情页）

> 给 **Claude Code** 的实施说明书。目标：把本包描述的 3 个新屏（+ 1 个共享顶栏组件）
> 实现进现有 Flutter 工程 `app/mls_app/lib/`，**复用已有 token 与 widget**，风格与现有屏一致。

---

## 0. 给 Claude Code 的第一条指令

> 阅读 `design_handoff_detail_screens/README.md` 全文。本包内 `prototype/` 里的 `.jsx` / `.html`
> 是**设计参考（React/HTML 原型）**，不是要照抄的生产代码——它们用来表达「最终长什么样、怎么交互」。
> 你的任务是**用本工程现有的 Flutter 环境与既有组件，把这些设计 1:1 还原**为 Dart 代码，
> 写进 `app/mls_app/lib/screens/` 与 `app/mls_app/lib/widgets/mls/`。
> 严禁硬编码颜色 / 字号 / 圆角 / 阴影，一律走 `MlsColors` / `MlsTypography` / `MlsRadius` / `MlsShadows`。

---

## 1. Overview（这是什么）

「张家口 MLS」是经纪人房源**联卖/协作**系统。本次新增 3 个**推入式详情页**，把现有列表/入口补成可下钻的真实导航：

| 屏幕 | 作用 | 从哪进入 |
|---|---|---|
| **房源详情** ListingDetailScreen | 看单套房源全貌、发起协作 | 房源列表的房源卡；房源详情底部「发起协作」 |
| **留痕时间线 · 成交确认签字** TraceScreen | 产品灵魂：双方独立留痕、互不可改、签字闭合后奖金自动结算 | 工作台 Hero「立即准备」、待办「成交确认待签字」、协作卡、通知项、房源详情里的带看记录 |
| **消息通知中心** NotificationScreen | 集中查看协作/成交/系统消息，标记已读 | 工作台头部的 `bell` 图标 |

外加一个共享组件 **MlsNavBar**（推入页统一顶栏：返回 + 标题 + 右槽）。

---

## 2. About the Design Files（设计文件说明）

- `prototype/*.jsx.txt` —— React 原型源码（`.jsx` 存为 `.txt` 仅为避免设计系统编译器误扫，**阅读/落地时当作 `.jsx`**）。**只作视觉与交互的事实来源**，不要移植 React。
- `prototype/preview/*.html` —— 4 个组件的独立预览卡（已内联样式，单独打开即可看清每个新组件的视觉细节）。
- `prototype/Shell.jsx.txt` —— 含 `NavBar`（即要实现的 `MlsNavBar`）的源码。

> token 对照见第 4 节映射表（CSS 变量 → Dart `MlsColors/...`），无需单独的 CSS 文件。

> 想看可点的完整原型：让用户在设计工具里打开 `ui_kits/mls_app/index.html`（本包外）。本包用于实现，无需运行。

---

## 3. Fidelity（保真度）

**高保真（hifi）。** 颜色、字号、间距、圆角、阴影都是最终值，请像素级还原。
所有视觉值都能在现有 token 里找到对应（第 4 节）。交互按第 8 节实现。

---

## 4. 复用现有资产（务必先读）

### 4.1 Token（全部已存在，直接引用）
`lib/theme/` 下：`MlsColors` / `MlsTypography` / `MlsRadius` / `MlsShadows`。

CSS 变量 → Dart token 映射（原型里出现的都在这）：

| 原型 CSS 变量 | Dart |
|---|---|
| `--primary` | `MlsColors.primary` (#2563EB) |
| `--primary-bg` | `MlsColors.primaryBg` |
| `--gold` | `MlsColors.gold` (#D97706) |
| `--success` / `--warning` / `--danger` / `--info` | `MlsColors.success/warning/danger/info` |
| `--text-primary/secondary/tertiary` | `MlsColors.textPrimary/Secondary/Tertiary` |
| `--text-on-dark` / `-muted` / `-subtle` | `MlsColors.textOnDark/OnDarkMuted/OnDarkSubtle` |
| `--border-light/mid/strong` | `MlsColors.borderLight/borderMid/borderStrong` |
| `--border-on-dark` | `MlsColors.borderOnDark` |
| `--grad-card` (`--grad-card-elevated`) | `MlsColors.cardElevated` |
| `--grad-panel-dark` | `MlsColors.panelDark` |
| `--bg-page-start/end` | `MlsColors.bgPageStart/bgPageEnd` |
| `--font-mono` | `MlsTypography.monoFamily` + `monoFallback` |
| `--r-sm/lg/xl/2xl/3xl` | `MlsRadius.sm(6)/lg(10)/xl(12)/xl2(14)/xl3(16)`；`--r-3xl`→`cardLg(16)`；`--r-pill`→`pill` |
| `--shadow-sm/md/lg` | `MlsShadows.sm/md/lg` |
| `--shadow-panel-dark` | `MlsShadows.panelDark` |
| 绿色 `#86EFAC` / `rgba(34,197,94,…)`（SECURED/签字） | 用 `MlsBadgeVariant.onDark` 的配色：bg `0x1A22C55E`、fg `0xFF86EFAC`、border `0x4D22C55E` |

> mono 数字记得 `fontFeatures: [FontFeature.tabularFigures()]`（等宽对齐），原型里 `tabular-nums` 的地方都要加。

### 4.2 现有 widget（直接复用，别重写）
`lib/widgets/mls/`：

| 原型组件 | 用现成的 |
|---|---|
| `Card` | `MlsCard(variant: …)`，变体 primary/elevated/dark/gold/hero/flat 已齐 |
| `Badge` | `MlsStatusBadge(text, variant, mono, icon, showDot)` |
| `Avatar` | `MlsAvatar`（按姓名 hash 取色，见 `MlsColors.avatarColorFor`） |
| `Btn`（primary/secondary/dark/full/size） | `MlsPrimaryButton`（核对其 API；缺 variant 就按 `MlsColors.buttonBlue/buttonDark` 渐变 + 对应 `MlsShadows` 补） |
| `ProgressStepper` | `MlsProgressStepper(steps, current)` |
| `SectionHeader` | `MlsSectionHeader` |
| 图标 | 原型用 lucide；Flutter 用 `Icons.*` 近义替换（第 7 节给每个图标的建议映射） |

> 实现前**先打开这些 widget 的 `.dart` 看真实构造参数**，以现有签名为准；本文档与代码冲突时以代码为准。

---

## 5. 要新建的文件清单

```
lib/widgets/mls/
  mls_nav_bar.dart            # 推入页统一顶栏（返回+标题+右槽，sticky）
  mls_spec_grid.dart          # 2 列 key-value 规格网格
  mls_trace_item.dart         # 留痕时间线单项（左轨 + 卡片）
  mls_notification_tile.dart  # 通知单项（圆形色图标 + 标题/副文 + 未读点）
lib/screens/
  listing_detail_screen.dart
  trace_screen.dart
  notification_screen.dart
```

外加：在路由层接线（第 9 节），并把现有入口的 onTap 指过去。

---

## 6. 新组件规格

### 6.1 MlsNavBar  （参考 `prototype/Shell.jsx` 的 `NavBar` + `preview/components-navbar.html`）
推入详情页顶部栏。`SliverAppBar`(pinned) 或自绘 `Container` + 外层 `CustomScrollView` 均可；要 **sticky 吸顶**。

- 高度 52；左 padding 6、右 8；子项横向排列，`crossAxisAlignment: center`，gap 8。
- **返回区**：40×40 命中区，圆角 `MlsRadius.lg`，居中放 `Icons.chevron_left`（size 24，stroke 2.2 视觉——Flutter 用 `Icons.chevron_left` 即可），点击 `Navigator.pop`。
- **标题区**（`Expanded`）：
  - 主标题 16 / w600 / letterSpacing -0.2，单行省略（`MlsTypography.cardTitleLg` 近似，颜色按 dark 切换）。
  - 可选副标题 `sub`：mono 9.5 / letterSpacing 1.5 / 大写 / tertiary（dark 时 `rgba(255,255,255,.6)`）。
- **右槽** `right`（Widget?）：可放图标按钮组或文字按钮（如「全部已读」12/w600/primary）。
- **`dark` 参数**：true 时文字白色、背景透明（叠在深色 hero 上，见 TraceScreen）；false 时浅色毛玻璃底——
  Flutter 没有 CSS backdrop-filter，用 `MlsColors.bgPageStart.withOpacity(0.86)` 纯色底 + 底部 0.5px `borderLight` 描边近似即可（**不要**强求毛玻璃）。

三种实测形态见 `preview/components-navbar.html`：①房源详情(右=分享+收藏两图标) ②消息通知(副标题 `03 UNREAD` + 右「全部已读」) ③成交确认(dark + 右 `SECURED` 绿标)。

### 6.2 MlsSpecGrid  （参考 `preview/components-specgrid.html`）
房源信息 2 列网格。`GridView`(`shrinkWrap`, `NeverScrollableScrollablePhysics`, crossAxisCount 2) 或两列 `Wrap`/`Table`。

- 入参：`List<({String k, String v})> items`。
- 列间距 12、行间距 14。
- 每格：上键 11 / tertiary；下值 14 / w600 / primary。
- **值的字体规则**：值里含数字或 `㎡` → 走 mono（`MlsTypography` mono 体）+ tabularFigures；纯中文 → sans。
- 外层通常包在 `MlsCard(variant: elevated)` 里，卡顶一行 mono 标签 `SPEC · 房源信息`（`MlsTypography.monoLabel`）。

### 6.3 MlsTraceItem  （参考 `prototype/TraceScreen.jsx` + `preview/components-timeline.html`）
留痕时间线单项 = 左侧竖轨（节点圆 + 连接线）+ 右侧 `MlsCard`。

- 入参建议：`side`（'BA'|'LA'|'SIGN'）、`icon`、`title`、`detail`、`time`、`hash?`、`done`、`current`、`future`、`isLast`。
- **左轨**（宽 30，`Column`，居中）：
  - 节点圆 30×30：BA 底 `primary @14%`、LA 底 `gold @14%`；`future` 时无底、改 1.5px 虚线描边 `borderStrong`。圆内放图标 size 15，颜色 BA=primary / LA=gold / future=tertiary。
  - `current` 时节点外加一圈呼吸光环（`mlsPulse` 动画：scale 1→1.6、opacity 0.6→0，2s 循环，颜色同侧色）。
  - 连接线（非末项）：宽 1.5，`done` 时实线（同侧色 @35%），未完成时虚线（`borderStrong`，7px 段 + 间隔）。
- **右卡**（`Expanded`，底部 padding 18，末项 0）：用 `MlsCard`——`future`→variant flat + 虚线边 + 透明底 + 无阴影；`current`→elevated；其余→primary。卡内：
  - 标题行：标题 13.5 / w600 / primary；右端 mono 侧标签 9 / w600 / letterSpacing 1（`BA 留痕` 蓝 / `LA 留痕` 金 / `PENDING` 灰），底为同色 @10%，圆角 `xs(4)`。
  - 描述：12 / secondary / line-height 1.5。
  - 元信息行：左 `MlsAvatar`(16) + mono 时间 10 / tertiary；右端（有 hash 时）`Icons.lock` 10 + mono 哈希 9.5 / tertiary。

### 6.4 MlsNotificationTile  （参考 `prototype/NotificationScreen.jsx` + `preview/components-notification.html`）
通知单项。整体可点（`MlsCard(onTap:)`）。

- 入参：`icon`、`accentColor`、`title`、`subtitle`、`time`、`unread`、`hasTraceLink`、`onTap`。
- variant：`unread` → elevated；已读 → flat + 整体 `opacity 0.82`。
- 布局 `Row`，`crossAxisAlignment: start`，gap 12：
  - 左：40×40 圆，底 `accentColor @12%`，居中图标 size 20 / accentColor。
  - 中（`Expanded`）：
    - 标题行：标题 14 / w600 / primary 单行省略；`unread` 时紧跟 7×7 红点（`MlsColors.danger`）；右端 mono 时间 10 / tertiary。
    - 副文：12 / secondary / line-height 1.5。
    - 若 `hasTraceLink`：下方一行「查看留痕 →」11 / w600 / primary（`Icons.north_east` 12）。

---

## 7. 屏幕规格

> 三屏都是：顶 `MlsNavBar` + 可滚动 body；房源详情/留痕另有 sticky 底部操作栏。
> 页面底色 `MlsColors.pageBg` 渐变。进入用 `Navigator.push`（含 iOS 右滑返回）。

### 7.1 listing_detail_screen.dart  （`prototype/ListingDetailScreen.jsx`）
入参：`listing`（名称/价格/单位/面积/状态/编号/accent 等）。自上而下：
1. **MlsNavBar**：标题「房源详情」，右槽 = 分享(`Icons.ios_share`/`Icons.share`) + 收藏(`Icons.bookmark_border`) 两个 40×40 图标按钮。
2. **照片廊**：高 188 圆角 `cardLg` 占位块（浅蓝灰渐变 `#E8EDF5→#DCE3EE` + 0.5px borderLight），居中放 `Icons.image`(40, 透明黑) + mono 占位文字「客厅 · PHOTO」。左上角 `MlsStatusBadge`(状态)，右上角 `1/6` mono 计数（白字、半透黑底 pill）。下方一排 6 段进度条（每段高 4 圆角 2，当前段 = accent，其余 = `黑@12%`），点击切换当前图（纯前端态）。
3. **标题/价格块**：房名 18 / w600 / -0.3；下方价格 = mono 30 / w700 / -1.5 / accent + 单位「万」14/w600/accent + 「单价 ¥20,185/㎡」body2；再下 4 个特征 chip（满五唯一/南北通透/精装/近地铁）：11 / secondary / 底 `黑@5%` / 圆角 sm / padding 4×9。
4. **SPEC 规格网格**：`MlsCard(elevated)` + `MlsSpecGrid`，8 项（户型/建筑面积/朝向/楼层/装修/建成年代/产权/挂牌编号）。
5. **LA 经纪人卡**：`MlsCard` 内 `Row`：`MlsAvatar`(42) + 姓名 14.5/w600 + 「LA · 挂牌」mono 微标(primary/primaryBg) + 副文「本房源由我挂牌 · 信誉 A · 成交 23」+ 右侧 38×38 电话按钮(`Icons.phone`, 底 primaryBg)。
6. **协作 · 带看记录**：section 标题行（左「协作 · 带看记录」+ 右 mono「2 条」）；下接若干 `MlsCard`，每张 = `MlsAvatar`(38, 在线点) + 伙伴名 + 角色 mono 微标(BA) + `MlsStatusBadge` + 副文「客户X · 时间」+ 右 `Icons.chevron_right`。**点击 → push TraceScreen**。
7. **sticky 底部操作栏**：左「共享到库」`MlsPrimaryButton(secondary, Icons.ios_share)`，右「发起协作」`MlsPrimaryButton(primary, full, Icons.handshake)` → push TraceScreen。

### 7.2 trace_screen.dart  （`prototype/TraceScreen.jsx`）——产品灵魂，重点还原
入参：`data`（listing 名、partner、role、customer、current）。结构：
1. **深色 Hero 区**（`MlsColors.panelDark` 渐变铺到状态栏后，注意把顶部 padding 顶进安全区）：
   - 顶部一条向下渐隐的绿色「扫描线」动画（`mlsScan`：从上往下扫，3.6s 循环，`linear-gradient(rgba(134,239,172,.12)→透明)`）。
   - **MlsNavBar(dark)**：标题「成交确认 · 留痕」，右槽 = `SECURED` 绿标（mono 9 / letterSpacing 1.5 / fg `#86EFAC` / 底 `绿@12%` / 0.5px `绿@30%` 边 / 圆角 sm）。
   - 房名 17 / w600 / 白；下方两个交叠 `MlsAvatar`(26, 2px 深色描边) + 说明「张三 LA · 李红 BA · 客户王先生」(onDarkMuted)。
   - 再下一块半透明容器（底 `白@5%` + 0.5px `borderOnDark` + 圆角 `r-2xl`）内嵌 **MlsProgressStepper**（steps=申请/同意/带看/发起/录入，current=4）。
2. **链路留痕**：标题行（`Icons.commit`/`Icons.timeline` + 「链路留痕」+ 右 mono「IMMUTABLE · 互不可改」）；下接 **5 个 MlsTraceItem**（数据见 `TraceScreen.jsx` 的 `trace` 数组：BA 发起→LA 同意→BA 带看→LA 发起成交(current)→双方签字(future)）。
3. **签字面板** `MlsCard(dark)`：标题行 `Icons.verified_user`(绿) +「双方独立签字 · 反作弊基石」；下方 2 列签字格，每格 = `MlsAvatar`(24) + 姓名/角色 + 状态行（`Icons.check_circle`(绿)+`SIGNED` / `Icons.radio_button_unchecked`(灰)+`PENDING`）。张三 LA 默认已签；对方默认未签。
4. **sticky 底部按钮**：未签时 `MlsPrimaryButton(dark, full, large, Icons.draw, '确认签字 · 留痕闭合')`；点击后**翻转状态**——对方签字格变 SIGNED（边框转绿）+ 按钮变 `primary, disabled, Icons.check, '已签字 · 奖金自动结算中'`。用 `StatefulWidget` 的 `bool signed` 即可。

### 7.3 notification_screen.dart  （`prototype/NotificationScreen.jsx`）
1. **MlsNavBar**：标题「消息通知」、副标题 `03 UNREAD`（无未读时 `ALL READ`）、右槽「全部已读」（有未读时 primary 可点、无未读 tertiary）。
2. **分段控件** `MlsSegmentedControl`（pill 变体）：全部 / 协作 / 成交 / 系统（点「系统」时把「提醒」类也并入）。
3. **列表**：按 `今天` / `更早` 分组，每组先一行 mono 组标题（`TODAY · 今天` / `EARLIER · 更早`，10 / letterSpacing 2 / 大写 / tertiary），下接 **MlsNotificationTile** 列表（数据见 `NotificationScreen.jsx` 的 `init`，6 条）。点项 → 标记该项已读；带 `trace` 的项额外 push TraceScreen。
4. 空态：某分类无数据时居中 `Icons.notifications_off` + 「没有这类消息 / 切换分类看看其他通知」。
5. 状态用 `StatefulWidget`：`List<Notif> items`（含 `unread`）、`String filter`；`全部已读` 把所有 `unread=false`。

---

## 8. 交互与状态汇总
- **导航**：均 `Navigator.push(MaterialPageRoute(...))`；MlsNavBar 返回键 `Navigator.maybePop`。
- **房源详情**：照片廊段选中态（`int currentPhoto`，纯前端）。
- **TraceScreen**：`bool signed`，签字翻转如 7.2.4。
- **NotificationScreen**：`filter` 切换 + `unread` 标记 + 全部已读，如 7.3.5。
- **动画**（`prefers-reduced-motion` 友好；列表项可做轻量入场错峰，非必须）：
  - `mlsPulse`（当前留痕节点呼吸）：scale 1→1.6 / opacity 0.6→0 / 2s / easeInOut / 循环。
  - `mlsScan`（成交页扫描线）：translateY 自上而下 / 3.6s / 循环。
  - `MlsCard` 自带按下 scale 0.98 反馈，沿用。

## 9. 路由接线（改现有文件）
把现有入口的 onTap 指向新屏（对照 `prototype/` 里各 screen 的 onOpen* 回调）：
- 房源列表 `listing_list_screen.dart`：房源卡 onTap → push `ListingDetailScreen(listing)`。
- 工作台 `home_screen.dart`：头部 `bell` → push `NotificationScreen`；Hero「立即准备」与待办「成交确认待签字」「带看留痕待录入」→ push `TraceScreen(data)`。
- 协作列表（协作 tab）：非「已结单」卡 onTap / 「查看详情」→ push `TraceScreen`；「已结单」维持现有庆祝弹窗。

## 10. Design Tokens
本次**不新增任何 token**，全部复用 `lib/theme/`（见第 4 节映射）。唯一需确认的是 `MlsTypography.monoFamily`（JetBrainsMono）已在 `pubspec.yaml` 注册——现有屏已在用，应已就绪。

## 11. 参考文件（本包内）
- **`screenshots/01-listing-detail.png` / `02-trace.png` / `03-notification.png`** —— **三屏成品截图**，实现时对照像素与配色最直观（手机壳为原型展示用，实现 Flutter 时忽略外壳，只看屏内内容）。
- `prototype/ListingDetailScreen.jsx.txt` / `TraceScreen.jsx.txt` / `NotificationScreen.jsx.txt` —— 三屏视觉/交互/数据事实来源（当作 `.jsx` 读）。
- `prototype/Shell.jsx.txt` —— `NavBar`（即 MlsNavBar）源码。
- `prototype/preview/components-navbar.html` / `-timeline.html` / `-notification.html` / `-specgrid.html` —— 4 个新组件的独立预览（已内联样式，直接打开看细节最清楚）。
- token 对照见第 4 节（CSS 变量 → Dart token）。
- （本包外）`ui_kits/mls_app/index.html` —— 可点完整原型，要走查交互时用设计工具打开。

---

### 验收清单
- [ ] 4 个新 widget 建好，全部走 token，无硬编码色值/字号。
- [ ] 3 屏可从对应入口 push 进入、可返回。
- [ ] TraceScreen 双方留痕色分（BA 蓝/LA 金）、mono 哈希、IMMUTABLE、签字翻转都对。
- [ ] 通知中心分组/未读点/标记已读/全部已读/分段筛选都对。
- [ ] 房源详情照片廊切换、SPEC 网格字体规则（数字 mono）、底部操作栏 sticky。
- [ ] 与现有屏放一起视觉一致（阴影/圆角/间距节奏）。
