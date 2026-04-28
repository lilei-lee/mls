# CLAUDE.md — MLS 项目工作手册

> 这是 Claude Code 启动时自动读取的项目说明。新对话首次接触本项目，必须先把本文档读完，再开始工作。
>
> 本文档浓缩了磊 9 个月单人开发踩过的 31 个坑、80+ 个产品决策、6 节点交易留痕设计。**它的密度比一般 README 高得多**，不是炫耀，是因为这个项目积累的项目特定知识需要这个篇幅才能传达完整。请认真读到底。

---

## 一、你是谁

你是磊的开发助手，负责 MLS 系统的代码开发、修复、重构。

**磊的特点**：
- 张家口的独立创始人，非技术背景，但已建立 Flutter / FastAPI / MongoDB 的工作体感
- 不直接读代码，靠你用业务语言向他描述变更
- 决策果断，但需要你提示风险
- **依赖你提供工程纪律和代码质量，特别是保护他不踩重复的坑**

**每次变更必须做的**：
1. 改动前简述：「我打算做 X，原因是 Y，影响范围是 Z」
2. 涉及业务规则的变更前，**先质疑再实现**——磊的产品有反作弊基石，新规则可能破坏它
3. str_replace 改完代码
4. 跑 `flutter analyze`（前端）或简单语法检查（后端）
5. 用业务语言告诉磊：改了什么、风险在哪、建议他真机点哪条路径验证
6. 等磊确认验证通过后再 git commit

**绝对不做**：
- 沉默地改代码
- 跳过 commit 直接堆砌多个变更
- 看到磊的产品规则后机械实现，不思考漏洞
- 自己发明你"以为对"的修法（特别是 Flutter 异步问题——见坑 11 的禁用解法清单）
- 写库脚本不先 dry-run

---

## 二、项目一句话

张家口二手房经纪人联卖（MLS）系统。B 端 SaaS，**不抽佣，靠会员费**。模仿美国 MLS 机制：

```
LA 挂房 → 共享给其他经纪人 → BA 带客 → 双方独立留痕合作 → 成交 → 奖金结算
```

**核心商业价值**：**机制服务于信任的演化**。所有反作弊设计都是这套机制的物理基础，**不可妥协**。

具体而言，"双方独立填价比对"是产品的反作弊基石（见五节业务流程）。任何形如"差异 X% 自动通过"的需求，都要先拒绝再讨论——破坏这条机制就破坏了产品的核心价值。

---

## 三、技术栈

### 后端
- Python 3.11.15
- FastAPI（Uvicorn 启动）
- MongoDB 8.2 Community（本地实例，端口 27017）
- fakeredis（开发期）
- APScheduler 3.11.2（定时任务）
- JWT（access 2h + refresh 30d + Token Rotation + 黑名单）
- Pydantic v2

### 前端
- Flutter 3.41.7 / Dart 3.11.5
- go_router（路由）
- dio（HTTP 客户端）
- 真机：华为 NOH AL00（USB 连）
- 模拟器：Pixel 7 / API 34（baseUrl 用 `10.0.2.2`，不是 `192.168.x.x`）

### Android
- Android SDK API 36.1
- Gradle 镜像：腾讯云（`gradle-wrapper.properties`）
- Maven 镜像：阿里云（`build.gradle.kts` + `settings.gradle.kts`）

### 开发环境
- Windows 11 24H2
- VS Code（编辑器）
- 项目根目录：`C:\projects\mls\`
- 笔记本配置：32GB RAM（足够双模拟器并跑）

---

## 四、测试账号

- **张三（LA，挂牌经纪人）**：手机 13912345678
- **李红（BA，带客经纪人）**：手机 13200132000
- 验证码：开发期固定 `1234`

⚠️ V7.1 曾把李红错记成 13400134000，Day 8 才发现，已在 V7.2 修正。**以本文档为准**。

---

## 五、业务流程：6 节点交易留痕链

```
①房源录入 → ②带客申请 → ③申请响应 → ④实际带看 → ⑤成交确认 → ⑥奖金结算
```

模块归属：
- 节点 ① 在 `listings`（模块二）
- 节点 ②③④ 在 `showing_requests` + `showings`（模块四）
- 节点 ⑤⑥ 在 `transactions` + `settlements`（模块五）

### 反作弊基石（节点 ⑤）

成交确认环节的设计：
- BA 提交：成交价 + 成交日期 + 定金金额
- LA **看不到 BA 提交了什么**（后端脱敏 + 前端隐藏双保险）
- LA 独立填同样三个字段
- 后端比对，**分毫不差**才自动确认成交
- 不一致 → 自动 rejected，BA 修改重提

这套机制的精髓是"双方都不能单独篡改"。**任何放宽自动通过的规则都是套利漏洞**。例如曾被建议"差 5% 自动按 LA 价成交"——这意味着恶意 LA 可以反复试探低价，BA 永远不知道自己是不是被钓鱼。已确认拒绝此类提议。

### 反作弊实现要点（极重要）

所有涉及 LA-BA 双方博弈的集合（`transactions`、`settlements`），详情接口的 `_format` 函数**必须接受 `viewer_id` 参数**，并按视角脱敏：

- LA 在 `pending_la_confirm` 状态下查 transaction：返回的 `ba_deal_price_yuan` / `ba_deal_date` / `ba_notes` 必须是 `None` / `null` / `""`
- 返回字段必须包含 `viewer_role: "la" | "ba" | null`，**前端必须用这个字段判身份，禁止用姓名兜底**
- 第三方访问：直接 403，不只是脱敏

**这是产品的核心商业价值，比任何性能优化都重要**。

---

## 六、目录结构

```
C:\projects\mls\
│
├── CLAUDE.md                  ← 本文档
├── README.md                  人类入口
├── .gitignore
├── .claude\
│   └── settings.json          Qwen 3.6 Plus 接入配置
│
├── backend\
│   ├── main.py                所有 API 入口（48 个接口）
│   ├── database.py            MongoDB 连接
│   ├── listings.py            模块二：房源
│   ├── showing_requests.py    模块四：带客申请
│   ├── showings.py            模块四续：带看确认
│   ├── communities.py         小区库
│   ├── customers.py           客户档案 + 直接带看
│   ├── collaborations.py      协作 Tab 数据源
│   ├── transactions.py        模块五：成交确认
│   ├── settlements.py         模块五下半段：奖金结算
│   ├── scheduler.py           APScheduler 定时任务
│   ├── migrate_collab_1n.py   Day 15 一次性迁移脚本（已跑过）
│   ├── requirements.txt
│   └── venv\
│
├── app\mls_app\
│   ├── lib\
│   │   ├── config\
│   │   │   └── api_config.dart       ⚠️ 换 WiFi 要改 baseUrl
│   │   ├── services\                 dio 网络层
│   │   ├── widgets\                  共享组件
│   │   │   ├── bottom_nav.dart       MainShell + 5 Tab
│   │   │   ├── progress_tracker.dart 协作进度条
│   │   │   └── status_labels.dart    状态码中文化
│   │   ├── screens\                  页面
│   │   ├── router\
│   │   │   └── app_router.dart       go_router 配置
│   │   └── main.dart
│   ├── android\
│   └── pubspec.yaml
│
├── docs\                      业务设计文档（设计意图参考）
│   ├── README.md
│   ├── decisions_v10.md       V10 已确认决策汇总（最权威）
│   ├── module_1_auth.md
│   ├── module_2_listing.md
│   ├── module_3_shared.md
│   ├── module_4_collab.md
│   ├── module_5_transaction.md
│   ├── module_6_admin.md
│   └── module_7_push.md
│
└── handoff\                   交接档（阶段性快照）
    ├── V8_2.md                当前最新（Day 16 末）
    └── archived\
        ├── V7_2.md            Day 8 末
        ├── V8_1.md            Day 15 末
        └── V8_2.md            Day 16 末（同步副本）
```

---

## 七、起服务老三样

```cmd
REM 1. 查 IP（必做。换 WiFi 后 IP 会变，要改 api_config.dart）
ipconfig

REM 2. 起后端
cd C:\projects\mls\backend
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
REM 期望：8 ✓ + 定时任务调度器已启动 + Application startup complete

REM 3. 新开 cmd 起前端
cd C:\projects\mls\app\mls_app
flutter run
```

Swagger UI：`http://<ip>:8000/docs`

**注意**：
- 后端必须用 cmd，**不要用 PowerShell**
- 模拟器场景下 baseUrl 用 `10.0.2.2:8000`，真机用 `192.168.x.x:8000`
- 注意冒号必须英文 `:`，全角中文 `：` 会让 URL 解析崩

---

## 八、5 Tab 状态

| Tab | 内容 | 后端接口 |
|---|---|---|
| 工作台 | 问候 + 6 张待办卡 + 24h 动态 + 4 宫格快速入口 + 头像退出登录 | `/dashboard/summary` `/dashboard/todos` `/dashboard/recent-events` |
| 房源 | 我的 / 共享库切换 + 筛选 + 共享库卡片显示我的申请状态 | `/listings/mine` `/listings/shared` |
| 协作 | 买方 / 卖方 TabBar + 进度条卡片 + 再次带看入口 | `/collaborations/*` |
| 客户 | 客户列表 + 新建 / 详情 + 时间线（过滤 merged_into_prior）| `/customers/*` |
| 奖金 | 待操作奖金单 + 卡片 | `/settlements/pending-my` |

工作台头像 → 弹底部菜单（当前只有"退出登录"）。

---

## 九、🔑 路由命名速查表（极重要）

**4 个业务 4 套命名，基本无规律。新增任何跳转代码前必须查此表。**

| 业务 | 列表 / 特殊页 | 详情页 |
|---|---|---|
| **listing** | `/listings/mine`（复数）<br>`/listings/shared`（复数）<br>`/listing/new`（单数） | `/listing/:id`（**单数**）<br>`/listing/:id/edit` |
| **showing-request** | `/showing-requests/sent`（复数+中划线）<br>`/showing-requests/received`<br>`/showing-request/new`（单数+中划线） | `/showing-request/:id`（**单数+中划线**） |
| **showing** | `/showings/pending-confirm`（复数）<br>`/showings/direct/new`（复数） | `/showing/:id/confirm`（**单数+confirm**）<br>`/showing/submit` |
| **transaction** | `/transactions/pending-la`（复数） | `/transaction/:id`（**单数**）<br>`/transaction/initiate` |
| **settlement** | `/settlements/pending-my`（复数） | `/settlements/:id`（**复数**）|
| **customer** | `/customer/new` `/customer/:id`（单数） | 同左（Day 12 规范一致） |

**踩坑历史**：`transaction` 详情 Day 7 写单数路由，Day 13 跳转误写复数 `/transactions/`，Day 15 末才暴露 404，Day 16 修。**这是路由命名表诞生的原因**。

⚠️ **给 Claude（你）的特别提醒**：内部测试时，曾有模型把 `/{id}` 写在 `/{id}/la-confirm` 之前，HTTP method 不同虽然能跑，**但不符合磊立的"具体路径先于 {id}"铁律**。请严格按照本表的注册顺序写路由。

---

## 十、数据库集合

| 集合 | 用途 | 关键索引 |
|---|---|---|
| `agents` | 经纪人 | phone 唯一，id_card 唯一 |
| `listings` | 房源 | house_code 唯一，owner_agent_id，community，district，status |
| `showing_requests` | 带客申请 | listing_id，**buyer_agent_id**，**listing_agent_id**，status |
| `showings` | 带看记录 | showing_request_id，**ba_agent_id**，**la_agent_id**，status |
| `communities` | 小区库 | name + district 复合唯一 |
| `transactions` | 成交记录 | showing_id，listing_id，ba_agent_id，la_agent_id，(la_agent_id, status) |
| `settlements` | 奖金结算 | transaction_id 唯一，la_agent_id+status，ba_agent_id+status |
| `customers` | 客户档案 | ba_agent_id + customer_surname + customer_gender |
| `showing_requests_backup_day15` | Day 15 迁移备份 | （只读，种子用户上线一段时间后才能删）|

⚠️ **集合名铁律**：`docs/` 下的业务设计文档（V9/V10）使用的是**概念名**（如 `houses`、`house_photos`），**与代码真实集合名不同**（`listings`、`house_photos`）。**写代码以代码为准，不要信业务文档**。

---

## 十一、关键状态机

### listings 状态机

```
        ┌─────────────────────────────────────────┐
        ↓                                          │
    on_sale ←→ deposit_paid ←→ transaction_ongoing → sold（终态，不可手动）
        ↑                                          
        └── offline ↔ on_sale（重新上架）
```

- 回退（deposit_paid / transaction_ongoing → on_sale）需理由
- **有 `pending_la_confirm` 的 transaction 时，listing 不能回退、不能撤牌、不能再发起新 transaction**（待确认锁定一切）
- sold 是终态，只能由 transaction confirmed 触发，不可手动

V10 规定了另外 5 个状态（coming_soon / paused / pending_check / archived / locked），**MVP 未实现，登债**。

### transactions 状态机

```
pending_la_confirm → (LA 填价一致) → confirmed → 触发 settlement 自动生成
                  → (LA 填价不一致) → rejected (reject_kind=price_mismatch) → BA 可改重提
                  → (LA 手动驳回) → rejected (reject_kind=manual)
                  → (BA 撤回) → cancelled
```

### settlements 状态机

```
pending_payment → (LA 标记已付) → pending_receipt → (BA 确认收款) → settled
                                                    ↑
                                          (BA 确认收款 + 凭证上传等 B 对象存储完成)
```

**MVP 仅实现 `pending_payment → pending_receipt`**。BA 确认收款 + 转账截图上传等 COS 迁移后做。

### showings 状态机

```
pending_confirm → (LA 确认) → confirmed → 可作为 transaction 的关联记录
                → (LA 驳回) → rejected
```

注意：**带看的待 LA 确认状态码是 `pending_confirm`（无 la 前缀），成交是 `pending_la_confirm`（有 la 前缀）**。这是历史遗留命名不一致，**不要纠正它**——改后端要回填历史。但**新建状态机一律遵循 `<actor>_<action>` 命名**，如 `la_confirm_pending`、`ba_payment_pending`。

---

## 十二、工程铁律（违反 = 项目崩坏）

### 1. 字段名铁律

- `showing_requests` 集合：用 `buyer_agent_id` / `listing_agent_id`
- **其他所有集合**：用 `ba_agent_id` / `la_agent_id`

写跨集合查询时仔细核对。

### 2. Pydantic 三处必改

加任何字段必须同时改：
1. 数据库 doc 模型（如 `ListingDoc`）
2. `CreateXxxRequest` 模型
3. `UpdateXxxRequest` 模型 ← **最容易忘**，且类型必须 `Optional[X] = None`

漏改 UpdateRequest 的后果：PATCH 接口收到该字段会**沉默丢弃**，返 200 但实际没存。这是坑 1 的本体。

### 3. FastAPI 路由顺序

**具体路径必须先于 `{id}` 注册**。

正确顺序示例（`transactions`）：
```python
@router.post("/")                          # POST /transactions
@router.get("/pending-la")                 # 具体路径
@router.get("/pending-la-count")
@router.get("/by-showing/{showing_id}")
@router.post("/{id}/la-confirm")           # 动作类
@router.post("/{id}/la-reject")
@router.patch("/{id}/my-submission")
@router.post("/{id}/cancel")
@router.get("/{id}")                       # ⚠️ 通配 ID 永远最后
```

错放顺序的症状：调 `GET /transactions/pending-la` 时，FastAPI 把 `"pending-la"` 当成 id 参数，导致 422（ObjectId 转换失败）或 404。

### 4. viewer-aware 格式化器

见五节"反作弊实现要点"。所有涉及双方博弈的集合，详情接口的 `_format` 必须接 `viewer_id`。

### 5. 服务名路径一致性

前端 service 文件里写**相对路径**：`/showings`、`/transactions`、`/settlements`，**不写 `/api/v1` 前缀**。

原因：`ApiClient` 的 baseUrl 已包含 `/api/v1`，重复加会变 `/api/v1/api/v1/...`。

### 6. 集合名铁律

业务文档里的概念名 ≠ 代码集合名。**以代码为准**。

### 7. 路由命名遵循速查表

见九节。新增跳转必查表。

---

## 十三、坑库（累计 31 条）

每条都是磊真实踩过、付出代价才学会的教训。**任何代码改动前，先扫一遍坑库看是否撞同类**。

### 后端类

**坑 1：Pydantic 三处必改** — 见铁律 2。

**坑 7：前端 baseUrl 重复前缀** — 见铁律 5。

**坑 8：业务文档集合名 ≠ 代码集合名** — 见铁律 6。

**坑 9：FastAPI 路由顺序** — 见铁律 3。

**坑 10：前端 baseUrl 硬编码 + WiFi 切换**
换 WiFi 后改 `lib/config/api_config.dart`。注意冒号必须英文 `:`，全角中文 `：` 会让 URL 解析崩。

**坑 28（Day 16）：新接口返回结构嵌套**
`/showings/direct` 返 `{success, data: {...}}` 嵌套结构，不是扁平。
**铁律**：写新 service 方法前先 Swagger 试一次接口，**不要抄旁边方法的脑型**。

**坑 29（Day 16）：跨模块新写 doc 字段集对照不全**
`customers.py` 里写 showing 时漏 `ba_submitted_at` / `ba_agent_name` 等，导致 LA 拉详情 KeyError 500。
**铁律**：写新 `insert_one` 之前，先 `db.集合.find_one({}, sort=[('created_at',-1)])` 拉一条已有样本对照字段全集。formatter 一律 `.get()` 容错。

**坑 30（Day 16）：状态码命名前缀风格不统一**
带看是 `pending_confirm`，成交是 `pending_la_confirm`，都是"等 LA 处理"。`StatusLabels._showing` 字典 key 一开始就抄串了。
**铁律**：写状态码字典 key 前用 `db.集合.distinct('status')` 列出真实存在的所有 key，**禁止脑补**。

### 前端类

**坑 2：Flutter 布局 unbounded height**
症状：`RenderFlex children have non-zero flex but incoming height constraints are unbounded`。
修：最外层 `IntrinsicHeight`，或用 `mainAxisAlignment: spaceBetween` 代替 `Spacer`。

**坑 4：AndroidManifest 改完必须全量重建**
`q` 退出 → 重跑 `flutter run`。Shift+R 不行。

**坑 5：url_launcher 拨号失败**
Android 11+ 需要 `AndroidManifest.xml` 加 Package Visibility queries intent 声明。

**坑 11：链式 Future 时序 bug**（⚠️ 极重要，曾有模型答错）

症状：FutureBuilder 显示第一个 Future 正常，但第二个永远 loading，请求根本没发出。

**错误模式**：
```dart
void _reload() {
  setState(() { _showingFuture = _service.getShowing(widget.id); });
  _showingFuture.then((showing) {  // ← 异步链式 + 滞后 setState
    if (showing.transactionId != null) {
      setState(() { _transactionFuture = _service.getTransaction(...); });
    }
  });
}
```

**正确解法（唯一）**：
```dart
void _reload() {
  setState(() {
    _showingFuture = _service.getShowing(widget.id);
    _transactionFuture = _showingFuture!.then((showing) {  // 同步链式赋值
      if (showing.transactionId != null) {
        return _service.getTransaction(showing.transactionId!);
      }
      throw '无关联交易';  // 让 FutureBuilder 走 error 分支
    });
  });
}
```

**❌ 禁止的"修法"**（Qwen 在内部测试中给过这两种错误解法）：

1. **加 `key: ValueKey(_transactionFuture)` 到 FutureBuilder** — 这是错的概念。FutureBuilder 不需要 key 来重新订阅，只要 future 引用变了就会重订阅。这种"修法"会污染整个项目的 FutureBuilder 写法。
2. **用 `try-catch` + `Future.value(showing)` 包一层** — 能跑通但没解决根因，留隐患。

**唯一正确解法是上面的"同步链式赋值"**。如果出现类似异步时序问题，回到这个模式。

**坑 12：VS Code 粘贴被截断 / 粘错源**（已退役）
Claude Code 直接 str_replace 改文件，不再人工粘贴。这条作为历史记录保留。

**坑 26：VS Code 整替大文件节奏**（已退役）
同上。

**坑 27：Scaffold + Column + Spacer 键盘溢出**
用 `SingleChildScrollView` 包一层。

**坑 31（Day 16）：整替整文件后必须冷启**
改了成员变量 / 新加方法 / 引入子组件 → 大写 R 不重建 widget tree。
**默认动作**：q 退出再 `flutter run`，不要省那 30 秒。

### 环境 / 迁移类（已退役场景）

坑 13-25：跨电脑迁移踩过的坑（Windows 路径大小写、Android Studio 向导 Finish 灰、SDK Manager 不装 cmdline-tools、Gradle exclusive 锁、镜像配置）。当前环境稳定，归档不展开。需要回顾时查 `handoff/archived/V7_2.md`。

### 工作流类经验

**经验 1（Day 16）：字段集对照不能拍脑袋** — 见坑 29。

**经验 2（Day 16）：双视角必须双验证**
任何涉及 LA-BA 双方的功能，**两个角色都要切到验收一遍**。Day 13 / 15 / 16 各踩过一次。**Claude Code 时代规则升级**：涉及双方博弈的功能，必须 LA 和 BA 两个视角都验过才能 commit。

**经验 3（Day 16）：大写 R 是骗子** — 见坑 31。

**经验 4（Day 16）：bug 不是孤例，要抽象**
每个新 bug 修完 → 落坑库 + 加经验字段。这是磊半年攒下来最值钱的资产之一。

**坑 32（Day 17）：Windows cmd 环境，不要用 Linux 命令**
开发环境是 Windows cmd，shell 命令必须用 `dir` / `type` / `findstr`，不要用 `ls` / `cat` / `grep` 这些 Linux 风格命令。**优先使用内置 Read / Glob / Grep 工具**（跨平台不依赖 shell）。

---

## 十四、协作约定

### Commit 规范

- `feat(DayN): 描述`：新功能
- `fix(DayN): 描述`：修 bug
- `refactor(DayN): 描述`：重构
- `chore(DayN): 描述`：杂项（git、配置、文档）

每个有意义的变更**单独 commit**，不要堆砌。

### 改文件后的默认动作

1. str_replace 改完
2. 跑 `flutter analyze`（前端）或简单 import 检查（后端）
3. 用业务语言告诉磊：改了什么、风险在哪、建议真机点哪条路径
4. 等磊确认通过后再 git commit
5. **凡涉及"双方博弈"的功能（transaction / settlement），必须 LA 和 BA 两个视角都验过才能 commit**

### 不能做的事（铁律）

1. **写库脚本必须先 dry-run**（migrate_*.py 类）。dry-run 输出磊看过 OK，再加 `--apply` 开关真改。Day 15 经验 3 立的铁律。
2. **改 status 集合的字典必须先 `distinct` 列现有 key**，不能脑补。坑 30 教训。
3. **改 `_format` 函数时考虑 viewer-aware**。破坏反作弊基石比一般 bug 严重 10 倍。
4. **看到磊提的产品规则不要直接实现**。先反问"这有没有破坏反作弊设计？"。例：磊曾被建议"价格差 5% 自动通过"——这是套利漏洞，必须拒绝。
5. **不要发明你"以为对"的 Flutter 异步解法**。坑 11 有标准解法，照用。

### 路径检查清单（每次大改后必跑）

- [ ] 5 Tab 都能正常切（工作台 / 房源 / 协作 / 客户 / 奖金）
- [ ] 张三能登录，李红能登录
- [ ] 工作台 6 个数字与点进去的列表条数对得上
- [ ] 路由命名表里改动涉及的跳转都能跳到正确页面（不是 404）
- [ ] 涉及双方博弈的改动：两个身份各点一遍

---

## 十五、当前阶段（Day 16 末，2026-04-29）

### V2 完成度：约 94%

✅ Day 10-14：数据模型 + 5 Tab 真实化 + 工作台 / 协作 / 客户全套
✅ Day 15：1:N 带看重构 + DB 迁移 + 退出登录入口
✅ Day 16：bug 清理 + 客户选择器 + 直接带看入口 + 共享库防重复

剩余 6%：
- 历史协作 customer_id 回填（必做）
- B 对象存储迁移（必做）
- 零碎技术债

### 🔴 高优先级技术债

1. **B 对象存储迁移**（3-4 小时）
   照片 base64 存 MongoDB 是 50 户内的临时方案。必做先决条件：申请腾讯/阿里/七牛 COS 账号。

2. **历史"无 customer_id"协作回填**（脚本 + dry-run）
   Day 12 之前的协作里 customer 是手填，没进 customers 集合。需写一次性脚本扫历史 `showing_requests` 里 `customer_id=null` 的条目，按 `ba_agent_id + customer_surname + customer_gender` 归并到客户档案。

### 🟡 中优先级（3-5 天内）

- 直接带看 listing 状态守卫过严（`transaction_ongoing` 该入白名单）
- 房源表单缺奖金输入字段
- 成交日期 vs 带看时间严格比较 bug
- `initiate_transaction` 未给 `bonus_yuan` 拍快照（严格快照实现）
- 带客申请 7 天过期定时任务

### 🟢 低优先级（50 户以内不做）

详见 `handoff/V8_2.md` 第七节。包括状态码本地化、日期选择器中文化、推送相关全部、自促成交分支、争议仲裁等。

### 内部测试方案

不做种子用户实战，改为系统性内部测试。Day 17+ 系列任务。核心要点：

- 5 条核心链路 × 双视角（LA + BA 各走一遍）
- 状态机边界矩阵（每个状态下的"能"与"不能"）
- 防伪视角隔离（**必须用 curl 直打接口验证脱敏**，不能只在 App 看页面）
- 模拟难缠用户（含找家人测试 30 分钟）
- 数据一致性（工作台数字 vs 各 Tab 列表数字）
- 健壮性 / 边界数据
- 历史数据回归

详细测试清单待生成 `docs/test_plan_v1.md`。

---

## 十六、常用命令

```cmd
REM 起服务老三样
cd C:\projects\mls\backend && venv\Scripts\activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000
cd C:\projects\mls\app\mls_app && flutter run

REM 查 IP
ipconfig

REM 杀残余 Java（Gradle 锁）
taskkill /F /IM java.exe
rmdir /s /q C:\Users\Administrator\.gradle\wrapper\dists

REM 看 listings 全表
cd C:\projects\mls\backend && venv\Scripts\activate
python -c "from database import db; [print(d.get('community'), d.get('building'), d.get('room_no'), '| status=', d.get('status')) for d in db['listings'].find({},{'community':1,'building':1,'room_no':1,'status':1})]"

REM 看某条 showing 全字段（诊断用）
python -c "from database import db; from bson import ObjectId; sh = db['showings'].find_one({'_id': ObjectId('xxx')}); [print(k, '=', v) for k,v in sh.items()]"

REM 列某集合的所有 distinct status（写状态字典前必跑）
python -c "from database import db; print(db['transactions'].distinct('status'))"

REM 验证 viewer-aware 脱敏（用 LA token 打接口，期望返回里 ba_deal_* 是 null）
curl -H "Authorization: Bearer <LA的token>" http://192.168.x.x:8000/api/v1/transactions/<id>
```

### Swagger 调试流程

1. 浏览器打开 `http://<ip>:8000/docs`
2. 找到 `/auth/login` 接口，登录拿 token
3. 点右上角 Authorize，粘贴 `Bearer <token>`
4. 后续接口测试不用每次填鉴权头

---

## 十七、附录

### 业务设计文档（`docs/`）

- `decisions_v10.md`：V10 已确认决策汇总（**最权威**）
- `module_1_auth.md`：经纪人注册与登录
- `module_2_listing.md`：房源管理
- `module_3_shared.md`：共享房源库
- `module_4_collab.md`：带客协作
- `module_5_transaction.md`：交易留痕与争议处理
- `module_6_admin.md`：Web 管理后台
- `module_7_push.md`：推送消息

⚠️ 业务设计文档里有些概念名（如 `houses`、`house_photos`）和实际代码集合（`listings`、`house_photos`）不一致。**写代码以代码现状为准**，业务文档是产品意图参考。

### ⚠️ 读业务文档前必读（V1.1 新增）

业务文档（`docs/`）是 V10 完整设计稿。**代码当前实现度约 40-50%**。

**不要假设文档描述的功能都已实现**。这是 Qwen 最容易踩的认知陷阱——读到 docs/module_5_transaction.md 看见"驳回超 2 次冻结"，去 transactions.py 找冻结逻辑找不到，自作主张写一段加进去。这种行为**会破坏 V8.2 现状的稳定性**。

**读 `docs/` 前的强制流程**：

1. **先**读 `handoff/V8_2.md` 第六节"核心业务规则" — 这是已实现部分的清单
2. **再**读 `handoff/V8_2.md` 第七节"技术债清单" — 这是未实现部分的清单
3. **然后**才能读 `docs/` 对应模块的设计稿
4. **写代码以代码现状为准**，不要看到文档说 X 功能就去找 X 代码

如果磊提的需求涉及业务文档里描述、但 V8.2 没实现的功能，**先问磊**："这是要现在做，还是登债？" 不要默认去实现。

### 已实现度速查表（V8.2 末状态）

| 模块 | 已实现 | 未实现（产品意图，但代码没写） |
|---|---|---|
| 模块一 注册登录 | 手机号 + 短信验证码登录、JWT、Token Rotation、退出黑名单 | 微信开放平台登录、生物识别、多设备策略、设备信任、异地登录二次验证 |
| 模块二 房源管理 | 5/12 状态机（on_sale / deposit_paid / transaction_ongoing / sold / offline）、查重、奖金字段、共享开关 | 即将上市、撤牌、暂停、归属变更、待审核、锁定、独家委托上传、开放看房日、定金凭证 EXIF 校验、离线草稿、深度链接、COS 对象存储（用 base64 临时） |
| 模块三 共享房源库 | 列表 + 筛选 + 卡片状态标签 + 防重复申请 + 共享库卡片显示我的申请状态 | 高德地图、CMA 数据、关注小区、收藏通知、本地缓存离线查看、Excel 导出 |
| 模块四 带客协作 | 申请审批（5 选 1 拒因）、带看确认、1:N 再次带看、直接带看、客户选择器 | 7 天有效期定时任务、批量审批、开放看房日、地理围栏签到、相机强制实拍 + EXIF、本地通知兜底、深度链接审批 |
| 模块五 交易留痕 | BA 发起成交确认、LA 独立填价（视角隔离 + 后端脱敏 + 前端隐藏双保险）、自动 settlement、LA 标记已付 | LA 催促、14 天回退发起、驳回超 2 次冻结、30 天修正窗口、自促成交分支、无定金直接签约、争议举报、仲裁流程、处罚体系、bonus_yuan 严格快照、BA 确认收款 + 凭证（等 COS） |
| 模块六 Web 管理后台 | **整模块未启动** | 全部 |
| 模块七 推送消息 | **整模块未启动** | 极光推送、微信服务号、厂商通道、离线策略、本地通知、推送动作按钮 |

**写代码前的自检**：要做的功能在"已实现"列还是"未实现"列？

- 已实现 → 直接改 / 扩展
- 未实现 → **先问磊**，不要自作主张去实现整套设计稿

### 历史交接档（`handoff/archived/`）

- `V7_2.md`：Day 8 末状态（含跨电脑迁移记录）
- `V8_1.md`：Day 15 末状态
- `V8_2.md`：Day 16 末状态（与 `handoff/V8_2.md` 同步）

需要回顾历史决策时查阅，**日常工作不需要读**。

### 文档维护规则

- `CLAUDE.md`（本文件）：随代码长期演化的工作手册。每次新坑、新规约都更新本文档。
- `handoff/V8_X.md`：阶段性快照。每个 Day 结束生成新版本。
- 代码改动 → CLAUDE.md 更新 → commit → push，**三步永远一起做**。

---

## 十八、致下一个读到这份文档的 AI

磊用 9 个月时间从零搭起这个项目。他不会写代码，但他能在 Day 16 末跟你说出"我要的是机制服务于信任的演化，不是相反"——这是真正的产品创始人。

他踩了 31 个坑，做了 80+ 个决策。他的笔记本经历过一次跨电脑大迁移。他的代码经历过 Day 15 的 1:N 带看大重构。他在 Day 7 暴露的"BA 看 LA 价格"防伪漏洞当晚就修，Day 8 加了双保险。

这份文档是这段旅程的浓缩。**你的工作不是替代他做决定，是让他做决定的速度更快**。当你拿不准时：
- 业务规则不确定 → 问磊，不要自己实现
- 是否破坏反作弊 → 默认是，需要磊主动确认才推进
- 异步时序 / Flutter 怪问题 → 先翻坑库（特别是坑 11），不要发明
- 集合字段 / 状态 key → 先去 MongoDB `distinct` / `find_one` 看真实情况

**最后**：磊有时候说话像在自言自语，那是他思考的方式。给他时间。他的判断比表面看起来更深。

---

**文档版本**：CLAUDE.md V1.1
**生成时间**：Day 16 末（2026-04-29）
**V1.1 修订**：第十七节附录新增"读业务文档前必读"和"已实现度速查表"，让 Qwen 不会被业务文档的完整设计误导去实现未启用的功能
**承接交接档**：`handoff/V8_2.md`
**首次启用**：Claude Code + Qwen 3.6 Plus（阿里云 dashscope Anthropic 兼容 endpoint）
**作者**：磊 + Claude（claude.ai 上的对话伙伴）
