# MLS 交接文档 V9.0(长期档 · 视觉规范 V2 + V2.2 #1 完工版)

> **更新时间**:Day 31 末(2026-05-14,实际写作日 2026-05-15)
> **关系**:V8.8 整档作废,V9.0 自包含,无需回看 V8.8 即可上手
> **承接**:V8.8 长期档(Day 25 末)+ Day 26-31 共 ~90 commit
> **本档主要变化**:
> - **V2.2 #1 完工**(社区 18 字段 + 房源 4 字段 + 共享库 5 类筛选 + 详情页 6-section 权限分层)
> - **视觉规范 V1 → V2 全工程接入**(AppTheme 旧体系下线,Mls 组件库 21 件,Design System v2.0)
> - **V6 数据大屏**(7 张卡 + 6 个图表组件 + 后端 `/dashboard/v6` 聚合接口)
> - **Q&A 问答系统**(模块四新增,4 API + 详情页 section + 我的提问页 + 待办)
> - **V3 段 1.1 起手**(多城多库架构 `db_router.py` + 数据迁移 `mls → mls_zhangjiakou`)
> - 坑账增量 60-62(V2.2 #1 撞坑)
> - V8.x 坑 1-59 浓缩为附录索引(完整内容查 V8.8)
> **下次开工锚点**:Day 32 · 工作树 3 项收尾(MlsProgressStepper / customer_id 必填 / 卡 7 overflow)+ V2.2 #2 或 V3 段 1.2 路线决策

---

## 一、版本与文档定位

### 1.1 V9.0 是什么

V9.0 是 MLS 项目的**长期档**——不记每日操作步骤,记需要长期承袭的:

- 项目基本信息(人 / 路径 / 栈 / 账号)
- 产品本体定义(角色 / 商业模式 / 核心机制)
- 架构铁律(违反则动地基)
- 数据归属字段表(V2.2 #1 后定型)
- 楼盘辞典架构
- API 接口实测全表(Day 31 末)
- 模块完成度盘点
- 坑账(诊断成本沉淀)
- 工作流铁律 + 命令速查
- V2.1 收官 + V2.2 #1 完工战报

**不属于本档**:每日 commit 日志、单步操作、模块详细 spec、临时决策的细节、Day 25 之前的历史坑账详情(查 V8.8)。

### 1.2 V9.0 vs V8.8

V8.8 在 Day 25 末定档,当时 V2.1 整体收官,Day 26 锚点是"V2.1 真机回归 + V2.2 / V3 路线决策"。**实际进度远超 V8.8 预期**——Day 26 起一周内完成:

- V2.2 #1(社区/筛选/详情)10+ 天工作量在 Day 26-32 间完成 18 commit
- 视觉规范彻底重做(AppTheme → Mls token,800+ 引用全工程迁移)
- Design System 从 v1 升级到 v2.0(双主色 + Lucide + Surface 分层)
- Q&A 问答系统从零落地
- V6 数据大屏(7 卡 + 6 图表组件)
- V3 段 1.1 多城多库架构起手(`db_router.py` + 数据迁移)

V8.8 → V9.0 关键差别:

| 维度 | V8.8(Day 25 末) | V9.0(Day 31 末) |
|---|---|---|
| 工程阶段 | V2.1 整体收官,待拉种子用户 | V2.2 #1 完工,视觉规范全工程接入,V3 段 1.1 起手 |
| 设计系统 | AppTheme(旧) | MlsTheme(新),旧体系彻底下线 |
| 数据库 | `mls`(单库) | `mls_zhangjiakou`(单城多库架构) |
| 房源字段集 | physical 5 + remarks(单字段) | physical 5 + 4 营销字段(sale_points 等) |
| 详情页 | 平铺 | 6-section 权限分层 + 社区迷你卡 |
| 共享库筛选 | 基础筛选 | 5 类新筛选(卖点/客观特征/装修/供暖/楼龄)+ 6 排序 |
| 工作台 | 数字卡 + 待办 | V6 数据大屏(7 卡 + 6 图表) |
| 问答机制 | 无 | Q&A 4 API + 详情页 section |
| Mls 组件库 | 无 | 21 件(token + 基础 + 专用) |

V8.8 整档作废:**V8.8 不再是当前 ground truth**,新会话开工密码只挂 V9.0。

### 1.3 适用场景

| 场景 | 操作 |
|---|---|
| 新会话开工 | 把 V9.0 + 当天起手任务挂进上下文 |
| 临时上下文丢失 | 把 V9.0 §九 战绩 + §八 模块完成度 贴回去 |
| 决策依据回查 | §四 铁律 + §五 数据归属 + §九 战绩 |
| 撞坑前自检 | §十 坑账 1-62(V8.x 坑 1-59 查 V8.8 详情) |
| API 联调 | §七 接口表(Swagger 实测) |
| 起新机器 | §二 项目基本信息 + §十四 命令速查 |
| 视觉/UI 改造 | §六 设计系统 + §十三 组件库索引 |

---

## 二、人 / 项目基本信息

### 2.1 人

**磊**:创始人 + 唯一开发者。张家口本地。Windows 11 笔记本(24H2)。**非技术背景**——通过与 Claude 协作开发,已建立对 Flutter / FastAPI / MongoDB / Git 的工作熟悉度,能独立完成"读懂报错 → 复述给 Claude → 验证 fix → commit push"全流程。

**操作偏好**:
- 终端**只用 cmd**,不用 PowerShell
- VS Code 是主 IDE,Android Studio **只用 SDK 管理**
- 真机调试:USB 直连华为 NOH AL00,不用 emulator
- **角色定位:客户,不是开发者**——技术诊断细节不需要解释,要的是结论

**协作模式**(三方分工):
```
磊(决策者)↔ Web 端 Claude Opus 4.7(顾问 / 架构 / 文档)↔ Claude Code(执行手 / 本地代码)
```

铁律 7 治理:Web Claude → 磊转发给 Code 的内容,如果是讨论 / 建议 / 复盘 → Code 必须先确认是否为指令,**不可直接动手**。

### 2.2 项目结构

```
C:\projects\
├── .gitignore                    archive/ 等私有目录排除
├── archive\                      测试数据备份(不入仓)
│
├── mls\                          MLS 主应用
│   ├── CLAUDE.md                 项目工作手册(V1.2 已过期,V2.0 待写)
│   ├── README.md                 人类入口
│   ├── .claude\settings.json     Code 接入配置 + permissions 白名单
│   │
│   ├── backend\                  FastAPI 后端,8000 端口
│   │   ├── main.py               所有 API 入口(~60 endpoint, 1484 行)
│   │   ├── database.py           MongoDB 连接
│   │   ├── db_router.py          ⭐ V3 段 1.1 新增:get_db(city) 多城路由
│   │   ├── dashboard_v6.py       ⭐ V6 大屏 5 卡聚合(208 行)
│   │   ├── listings.py           模块二:房源
│   │   ├── showing_requests.py   模块四:带客申请
│   │   ├── showings.py           模块四续:带看确认
│   │   ├── communities.py        小区库(V2.2 #1 加 18 字段富化)
│   │   ├── customers.py          客户档案 + 直接带看
│   │   ├── collaborations.py     协作 Tab 数据源
│   │   ├── transactions.py       模块五:成交确认
│   │   ├── settlements.py        模块五续:奖金结算
│   │   ├── qna.py                ⭐ V2.2 #2 新增:Q&A 问答 4 API
│   │   ├── scheduler.py          APScheduler 定时任务
│   │   ├── services\             ⭐ 拆分服务层
│   │   │   ├── listing_filter.py    batch_fetch + passes_dict_filters
│   │   │   └── listing_enrich.py    enrich_from_dictionary
│   │   ├── const\sale_points.py  ⭐ 21 预设标签 + 4 自定义槽
│   │   ├── utils\
│   │   │   ├── anonymize.py      ⭐ Q&A 脱敏 (姓+*)
│   │   │   └── collaboration_status.py  ⭐ is_collaboration_unlocked
│   │   └── tests\                116 tests
│   │
│   ├── app\mls_app\              Flutter App
│   │   ├── lib\
│   │   │   ├── config\api_config.dart  ⚠️ 换 WiFi 要改 baseUrl
│   │   │   ├── theme\            ⭐ 6 个 Mls token 文件
│   │   │   │   ├── mls_colors.dart
│   │   │   │   ├── mls_typography.dart
│   │   │   │   ├── mls_radius.dart
│   │   │   │   ├── mls_shadows.dart
│   │   │   │   ├── mls_animation.dart
│   │   │   │   └── mls_theme.dart
│   │   │   ├── widgets\mls\      ⭐ 21 个 Mls 组件
│   │   │   ├── widgets\          共享组件
│   │   │   ├── screens\          页面
│   │   │   │   ├── dashboard_screen.dart    ⭐ V6 大屏(~470 行)
│   │   │   │   ├── community_detail_screen.dart  ⭐ V2.2 #1 新增
│   │   │   │   ├── my_questions_screen.dart      ⭐ V2.2 #2 新增
│   │   │   │   ├── qna_list_screen.dart          ⭐ V2.2 #2 新增
│   │   │   │   └── ...(其他保留)
│   │   │   ├── services\
│   │   │   │   ├── dashboard_service.dart   ⭐ v6() 方法
│   │   │   │   ├── qna_service.dart         ⭐ V2.2 #2
│   │   │   │   └── ...
│   │   │   ├── router\app_router.dart
│   │   │   └── main.dart(已切 MlsTheme.light)
│   │   ├── android\
│   │   └── pubspec.yaml
│   │
│   └── docs\                     业务设计 + 历史档(命名已英文化)
│
└── property-dictionary\          楼盘辞典服务(独立,8001)
    └── backend\
        ├── main.py
        ├── communities.py        18 字段 schema + batch endpoint
        ├── properties.py         objective_features + decoration claim
        └── tests\                87 tests
```

**路径速查**:

| 服务 | 路径 |
|---|---|
| MLS 项目根 | `C:\projects\mls\` |
| MLS 后端 | `C:\projects\mls\backend\` |
| MLS 前端 | `C:\projects\mls\app\mls_app\` |
| 辞典后端 | `C:\projects\property-dictionary\backend\`(⚠️ V8.8 写的是 `C:\projects\mls\property-dictionary`,实际是 monorepo 根的 `property-dictionary`,V9.0 修正) |
| MongoDB 数据 | `C:\data\db\` |
| archive 备份 | `C:\projects\archive\`(.gitignore) |
| 长期档 | `C:\projects\mls\docs\MLS交接文档V9_0.md`(本档) |

### 2.3 技术栈

**后端**:
- Python 3.11.15
- FastAPI(Uvicorn 启动)
- MongoDB 8.2 Community(本地实例,端口 27017)
- fakeredis(开发期)
- APScheduler 3.11.2(定时任务)
- JWT(access 2h + refresh 30d + Token Rotation + 黑名单)
- Pydantic v2

**前端**:
- Flutter 3.41.7 / Dart 3.11.5
- go_router(路由)
- dio(HTTP 客户端)
- lucide_icons 0.257(图标库,V2 主用)
- 真机:华为 NOH AL00(USB 连)
- 模拟器:Pixel 7 / API 34(baseUrl `10.0.2.2`,不是 `192.168.x.x`)

**Android**:
- Android SDK API 36.1
- Gradle 镜像:腾讯云
- Maven 镜像:阿里云

### 2.4 测试账号

| 账号 | 手机号 | 角色 | 备注 |
|---|---|---|---|
| 张三 | 13912345678 | LA | 主测挂牌 |
| 李红 | 13200132000 | BA | 主测带客 |
| 验证码 | — | — | `123456`(开发态固定,生产前必换真 SMS) |

### 2.5 GitHub 远端

- 仓库:`git@github.com:leelei-hub/mls.git`(monorepo,私有)
- 主分支:`main`
- Day 31 末:本地 = origin/main 同步,HEAD `393dfae`
- 推送策略:granular commit,每个独立改动一个 commit

### 2.6 真机网络配置

每次 Windows 重启后 PC IP 可能变(局域网 DHCP),`ipconfig` 查 IPv4。

App `lib/config/api_config.dart` 的 `baseUrl` 必须是 PC 局域网 IP(非 localhost / 127.0.0.1 / 10.0.2.2),否则真机连不到后端。每次 IP 变了要改 + Flutter hot restart 才生效。

---

## 三、产品本体与商业模型

### 3.1 一句话定义

**MLS = 张家口二手房经纪人协作系统**。B2B SaaS,会员费制,服务于本地中介经纪人之间的房源共享 + 带客协作 + 反作弊交易留痕。

### 3.2 名称与边界

- 中文名:**张家口二手房经纪人协作系统**
- 英文缩写:MLS(借用美国 Multiple Listing Service 概念,但商业模式不同)
- 覆盖城市:**张家口**(单城起家,V3 段 1.x 已为多城预留架构)
- 覆盖业态:**二手房**(新房 / 商铺 / 写字楼后续)
- 不覆盖:C 端用户(经纪人之间的工具)

### 3.3 角色定义

```
经纪人(agent)─┬─ LA(Listing Agent / 挂牌经纪人)── 持房源,赚 LA 费 + 合作奖金
              └─ BA(Buyer Agent / 买方经纪人)── 带客户,赚 BA 费 + 合作奖金

同一经纪人可同时是 LA 和 BA(自促成交场景)。

门店账号(broker)── 老板账号,具备完整经纪人身份 + 管理下属经纪人。
                     角色切换器(门店管理 / 个人经纪人)在工作台顶部。
```

### 3.4 商业模型

**会员费制**,**不抽成**。

| 维度 | 传统平台(贝壳类) | MLS |
|---|---|---|
| 收入来源 | 抽成(每笔成交 X%) | 会员费(月/年付) |
| 利益对齐 | 平台希望多成交 | 平台希望经纪人留得住 |
| 经纪人感知 | 平台是分蛋糕的 | 平台是工具 |

会员费收谁:个人经纪人 + 门店账号(broker)。**不向购房者收费**。

**会员费收取的技术机制(Day 32+ 实现,真机待验)**:

- 全局开关 `config.MEMBERSHIP_ENFORCED`(env,默认 `false`):
    - `false` = 免费试用期 → 人人完整可用,不拦任何写操作
    - `true` = 收费期 → `agents.membership_expires_at` 在未来 = 有效会员;否则**全功能只读**
- **不设固定试用天数**(`MEMBERSHIP_TRIAL_DAYS=0`),完全靠开关 + 后台手动开通(磊 2026-06-14 决策)
- 只读拦截:`main.py` HTTP 中间件,收费期内过期会员的「非 GET 且非 `/api/v1/auth/*`」请求返 **402**;放行登录/注册/看
- 前端:dio 拦截器拦 402 → 全局 SnackBar 友好提示;「我的」页账户区显示会员状态 + 过期时红色只读横幅
- 状态查询:`GET /api/v1/membership` + `/me` 增 `membership` 字段(`enforced/active/read_only/expires_at/days_left`)
- 后台开通/续期:`backend/scripts/grant_membership.py <手机号> <天数>`(Web 会员后台做好前的运维工具)
- 自测:9 纯单测 + mongomock+TestClient 10/10 端到端(免费期不拦 / 收费期过期写 402 / GET+auth 放行 / 后台开通恢复 / 状态接口)。**真机两条路径(免费期 / 收费期)待磊侧冷启验证**

### 3.5 核心理念

**机制服务于信任的演化**。

平台不是中立工具,是信任机制的载体。经纪人之间合作有博弈(怕截客 / 怕压价 / 怕分赃不均),平台通过机制设计让"诚实合作"是 dominant strategy:

- 共享房源库 + 身份隐藏(BA 看不到 LA 联系方式,直到 LA 批准带看)→ 防截客
- 带客申请双向通过制 + 失败原因留档 → 防滥用
- **反作弊基石**:LA 独立填价 + 系统比对(分毫不差才通过)→ 防成交压价
- audit_log 全留痕 → 事后追溯

### 3.6 核心机制:6 节点交易留痕

```
①房源录入 → ②带客申请 → ③申请响应 → ④实际带看 → ⑤成交确认 → ⑥奖金结算
```

| 节点 | 名称 | 关键留痕 | 所属模块 |
|---|---|---|---|
| ① | 房源录入 | LA + 房源信息 + 独家委托协议 | 模块二 listings |
| ② | 带客申请 | BA + 客户姓氏/性别/需求 | 模块四 showing_requests |
| ③ | 申请响应 | LA 同意/拒绝 + 联络动作 | 模块四 |
| ④ | 实际带看 | 带看时间 + 现场凭证 + 双方确认 | 模块四 showings |
| ⑤ | 成交确认 | **双方独立填价比对** + 成交日期 + 定金 | 模块五 transactions |
| ⑥ | 奖金结算 | LA 确认已付 + BA 确认已收 | 模块五 settlements |

### 3.7 商业层级:辞典 vs MLS(资产 vs 产品)

```
楼盘辞典(独占数字资产)            ← 数据飞轮
    ↓ HTTP REST + X-API-Key
MLS 张家口实例(可被接入的应用)
```

辞典是独立的"数字资产层",MLS 通过 `X-API-Key` HTTP REST 调用辞典。**物理字段**(面积、户型、楼龄、客观特征、装修等)归辞典管,**业务字段**(价格、状态、奖金、备注、卖点)归 MLS 管。

V2.2 #1 后,辞典管的字段大幅扩展:
- communities:18 字段(楼龄/物业/供暖/教育/交通/生活/车位)
- properties:5 物理字段 + objective_features(14 枚举) + decoration(5 枚举)

---

## 四、架构铁律

铁律 = 违反则动地基。这一节是 V9.0 最严格的部分,**11 条全部承袭 V8.8/CLAUDE.md V1.2**,不可放宽。

### 4.1 协作铁律(11 条)

1. **写库脚本必须先 dry-run**——写库 step 必须有"用户审核 dry-run 输出"暂停点
2. **改 status 字典必须先 distinct 列现有 key**——任何状态机改动前先看 DB 真实状态
3. **FastAPI 路由顺序**:具体路径必须先于动态 `{param}` 路径注册(否则静态路径被吞当参数解析)
4. **改 `_format` 函数必须考虑 viewer-aware**——反作弊基石,详情接口必须接受 `viewer_id` 参数并按视角脱敏
5. **不要发明 Flutter 异步解法**——坑 11 有标准解法,照用,不要自己想新解
6. **看产品规则不要直接实现,先反问**——磊提的产品规则可能破坏反作弊基石,先反问"这有没有破坏反作弊设计?"
7. **协作分工边界**——Code 只接磊明确发出的、可立即执行的指令。Web Claude 转发的讨论/建议/复盘,Code 必须先确认是否为指令
8. **多步修改前必须先输出 PLAN**——2 步以上的代码修改必须先输出 PLAN(每步标 [只读]/[改代码]/[写库]),等磊回 ok 才执行
9. **只读命令必须贴原文**——grep/cat/find/curl/git log 的结果必须完整贴给磊,不要总结/省略/分类
10. **代码写完先静读自检**——`create_file`/`str_replace` 完成后先 echo 一次代码,逐行检查再发审批
11. **严守任务范围,不要顺手优化**——磊说改 N 处只改 N 处,不要扩成 N+1。发现优化机会先停下报告

### 4.2 反作弊基石(实现要点)

**这是产品的核心商业价值,比任何性能优化都重要**。

所有涉及 LA-BA 双方博弈的集合(`transactions`、`settlements`、`qna`),详情接口的 `_format` 函数**必须接受 `viewer_id` 参数**:

- **mask 触发条件按"业务保密区间"设计,不按"业务流程瞬间"设计**(Day 17 经验 5)
  - ❌ `mask_ba = is_la and status == "pending_la_confirm"`(只在瞬间脱敏)
  - ✅ `not_confirmed = status != "confirmed"; mask_ba = is_la and not_confirmed`(覆盖所有未成交)
- **mask 必须双向**——LA 看 BA 字段要 mask,BA 看 LA 字段也要 mask
- 返回字段必须包含 `viewer_role: "la" | "ba" | null`,**前端必须用这个字段判身份,禁止用姓名兜底**
- 第三方访问:直接 403,不只是脱敏

**反作弊**:LA 独立填价 + 系统比对,**分毫不差才自动确认**。任何"差异 X% 自动通过"的需求都是套利漏洞,直接拒绝(磊已确认拒绝过此类提议)。

### 4.3 辞典数据归属铁律

V2.2 #1 后定型:

- **辞典管的字段**(communities + properties):MLS 不能直写,必须走 `sync-physical` 经辞典裁决
- **MLS 管的字段**(listings 营销字段、协作链、奖金):辞典只读不写,通过 `transaction_history` 单向 sink
- **跨服务数据通信**:HTTP REST + `X-API-Key`,辞典 5xx 时 MLS 进 retry 队列(V3 实施 scheduler)
- **用户字段缺失**:必须 400 拒绝,**不能** silent skip(坑 38 教训)

### 4.4 视觉规范铁律(V2 起新增)

视觉规范 V2 全工程接入后:

- **所有新组件必须用 Mls 系列**(MlsCard / MlsAvatar / MlsStatusBadge 等),禁止使用废弃的 AppCard / AppAvatar / AppSection
- **所有颜色/字号/圆角/阴影必须用 token**(MlsColors.* / MlsTypography.* / MlsRadius.* / MlsShadows.*),禁止硬编码
- **5 字漂上来 bug 治理**:任何无 FAB 的 Tab 必须加 `floatingActionButton: SizedBox.shrink()`(IndexedStack 嵌套场景下 body 顶部 leak BottomNav label 渲染)
- **入场动画**:倒计时 / 进度环 / 脉冲 / 扫描线 → MlsPulse / MlsCountdownClock / MlsProgressRing 已封装,直接复用

---

## 五、数据归属字段表(V2.2 #1 后定型)

### 5.1 listings 字段(MLS 主)

**物理字段(必走辞典裁决,不可直写)**:
- `area_sqm`(面积) → 辞典 properties
- `rooms / bathrooms / orientation / house_structure`(户型) → 辞典 properties
- `objective_features`(14 客观特征,V2.2 #1 新增) → 辞典 properties
- `decoration`(5 装修选择,V2.2 #1 新增) → 辞典 properties

⚠️ **删除字段**(V2.2 #2 已删):`halls`(改为 `house_structure` 6 枚举更精确)

**MLS 私有营销字段**(V2.2 #1 新增 4 字段,删 `remarks`):
- `sale_points`(卖点标签,21 预设 + 4 自定义 ≤12 字)
- `public_remarks`(房源描述,展示给所有人)
- `agent_remarks`(同行私话,仅协作通过后可见)
- `showing_instructions`(带看说明,仅协作通过后可见)

**MLS 业务字段**:
- `price_wan`(价格,变动时自动 `$push price_history`)
- `bonus_yuan`(合作奖金)
- `status`(状态机,见 §5.4)
- `house_code`(唯一键)
- `community / district / building / room_no`(地址)
- `layout_image_url`(户型图,V2.2 #5 新增)
- `listed_at`(挂牌时间)

### 5.2 communities 字段(辞典主)

V2.2 #1 加 18 字段(全 Optional,旧文档兼容):

| 分类 | 字段 |
|---|---|
| 基础 | `bld_year_start`, `bld_year_end`, `total_buildings`, `total_units` |
| 规划 | `plot_ratio`, `green_ratio` |
| 物业 | `property_company`, `property_fee_yuan`, `building_types` |
| 供暖 | `heating_type` |
| 教育 | `primary_school`, `middle_school` |
| 交通 | `nearest_highway`, `nearest_train_station` |
| 生活 | `nearby_market`, `nearby_hospital` |
| 车位 | `parking_total`, `parking_ratio` |

MLS 通过 `_enrich_community_from_dict` 富化到详情页"社区迷你卡"。

### 5.3 数据库集合速查

| 集合 | 用途 | 关键索引 |
|---|---|---|
| `agents` | 经纪人 | phone 唯一,id_card 唯一 |
| `listings` | 房源 | house_code 唯一,owner_agent_id,community,district,status |
| `showing_requests` | 带客申请 | listing_id,buyer_agent_id,listing_agent_id,status |
| `showings` | 带看记录 | showing_request_id,ba_agent_id,la_agent_id,status |
| `communities` | 小区库(辞典) | name + district 复合唯一 |
| `transactions` | 成交记录 | showing_id,listing_id,ba_agent_id,la_agent_id,(la_agent_id,status) |
| `settlements` | 奖金结算 | transaction_id 唯一,la+status,ba+status |
| `customers` | 客户档案 | ba_agent_id + customer_surname + customer_gender |
| `qna_threads` | Q&A(V2.2 #2 新增) | listing_id, asker_id, owner_id |
| `*_backup_dayN` | 重大迁移备份 | 只读,种子用户上线后才能清 |

⚠️ **集合名铁律**:`docs/` 业务文档使用**概念名**(houses, house_photos),代码用真实集合名(listings)。**写代码以代码为准**。

### 5.4 listings 状态机

```
        ┌─────────────────────────────────────────┐
        ↓                                          │
    on_sale ←→ deposit_paid ←→ transaction_ongoing → sold(终态,不可手动)
        ↑                                          
        └── offline ↔ on_sale(重新上架)
```

- 共享库可见:`on_sale / deposit_paid / transaction_ongoing / sold`(offline 不可见)
- 可被发起带看:`on_sale / deposit_paid`
- 回退(`deposit_paid / transaction_ongoing → on_sale`)需理由
- 有 `pending_la_confirm` 的 transaction 时,listing 不能回退、不能撤牌、不能再发起新 transaction
- sold 是终态,只能由 transaction confirmed 触发,不可手动

### 5.5 transactions 状态机

```
pending_la_confirm → confirmed(双方填价一致)
                  → rejected(不一致,可重提)
                  → cancelled
```

反作弊核心:`status != "confirmed"` 时双方互相不可见,mask 必须双向。

---

## 六、设计系统 V2.0(Day 26-31 新增章节)

### 6.1 设计语言

| 维度 | V1(已废) | **V2.0**(当前) |
|---|---|---|
| 主色 | 单色品牌蓝 | **双主色:Primary 蓝 + Gold 金** |
| 中性色 | 9 档 grey | 10 档 n0-n900 |
| 表面 | 单层 | **Surface 4 层 + Shadow 5 级** |
| 渐变 | 无 | **3 种 Gradient**(Hero / Card / Banner) |
| 圆角 | 3 档 | 4 档(small/m/l/xl) |
| 字号 | 9 档 | Display + 4 Title + 3 Body + Caption + 3 Number |
| 图标 | Material | **Lucide**(主用,22px/18px) |

### 6.2 Mls Token 层(6 文件)

`app/mls_app/lib/theme/mls_*.dart`:

- `mls_colors.dart`——Primary/Gold/Neutral/Surface/Functional 全色板,含 V6 dashboard/charts 5 常量
- `mls_typography.dart`——Display/Title/Body/Caption/Number 全字号
- `mls_radius.dart`——4 档圆角
- `mls_shadows.dart`——5 级阴影
- `mls_animation.dart`——入场 / 脉冲 / 扫描线 timing 常量
- `mls_theme.dart`——`MlsTheme.light` 入口(已在 `main.dart` 切换)

### 6.3 Mls 组件库(21 件)

**基础组件**(6):
- `MlsCard`(6 variant:primary/elevated/dark/gold/hero/flat,可点击 scale 反馈)
- `MlsAvatar` + `MlsAvatarStack`(渐变头像 + 协作 row 横向叠加)
- `MlsStatusBadge`(7 variant + dense/mono + onDark 反作弊用)
- `MlsPrimaryButton`(6 variant + 3 size + loading/disabled)
- `MlsSectionHeader`(badge + leadingIcon + trailing 三态)
- `MlsSegmentedControl`(pill + underline 两 variant)

**专用组件**(7):
- `MlsCountdownClock`(秒数闪烁,Timer.periodic 每秒刷新)
- `MlsHeroToday`(工作台焦点大卡,蓝渐变 + 倒计时 + 协作头像 stack + CTA)
- `MlsMetricCell` + 配套 `MlsProgressBar` / `MlsMiniBars` / `MlsSparkline`
- `MlsProgressRing`(环形进度,CustomPainter + 入场动画)
- `MlsProgressStepper`(5/6 节点进度链,当前节点 pulse + 通往当前虚线"独立断开"叙事)
- `MlsEncryptedPanel`(反作弊基石视觉化身,3s 扫描线动画 + 字段遮罩 ▓▓▓ + SECURED 徽章)
- `MlsMoneyInput`(价格输入,千分位实时格式化 + 万元换算徽章 + "请勿填万元"警告)

**V6 大屏专用图表组件**(6):
- `MlsDualBarChart`(双柱图)
- `MlsDualLineChart`(双折线)
- `MlsFunnelChart`(转化漏斗)
- `MlsDonutChart`(甜甜圈)
- `MlsMedalGrid`(8 级徽标网格)
- `MlsMedalInline`(行内徽标)

**动效辅助**(2):
- `MlsPulse`(脉冲动画,⚠️ 用在固定大小容器内必须 SizedBox + ClipRect + OverflowBox 包,否则 RIGHT OVERFLOW)

### 6.4 旧体系下线

- `AppTheme` / `AppCard` / `AppAvatar` / `AppSection` 全工程引用 800+ → 3 → 0
- 4 个旧文件已删:`app_theme.dart` / `app_card.dart` / `app_avatar.dart` / `app_section.dart`
- 40 处 `import app_theme` 已清
- `STYLE_GUIDE.md`(66 行)锁定视觉规约 + 派工模板

---

## 七、API 接口实测全表(Day 31 末)

**约 60 endpoint,V8.8 基础 + V2.2 #1/#2 增量**。完整 Swagger:`http://<ip>:8000/docs`。

### 7.1 V2.2 #1/#2 新增接口(增量,V8.8 后)

| Method | Path | 用途 | 鉴权 |
|---|---|---|---|
| POST | `/v1/communities/batch` | 批量社区查询(辞典) | API Key |
| GET | `/communities/{id}/detail` | 社区档案 + 统计 + 预览 | JWT |
| GET | `/communities/{id}/listings` | 社区在售房源(room 过滤+分页) | JWT |
| GET | `/communities/{id}/deals` | 社区成交(V3 占位) | JWT |
| GET | `/listings/{id}/showings-summary` | LA 视角带看汇总 | JWT(仅 LA) |
| GET | `/listings/shared` | 共享库(加 5 类筛选 + 6 排序 + community_id) | JWT |
| GET | `/qna/list?listing_id=` | Q&A 列表 | JWT |
| POST | `/qna/ask` | BA 提问 | JWT(BA) |
| POST | `/qna/answer` | LA 回答 | JWT(LA) |
| DELETE | `/qna/{thread_id}` | 软删 | JWT |
| GET | `/qna/my` | BA 我的提问汇总 | JWT(BA) |
| GET | `/qna/my/pending-count` | 待回答计数 | JWT |
| GET | `/transactions/pending?filter=la\|ba` | 双视角合并 pending | JWT |
| GET | `/dashboard/v6` | V6 大屏 5 卡聚合 | JWT |

### 7.2 共享库筛选参数(Day 26 重写)

`GET /listings/shared` 现支持:

```
基础:
  district, room_count, area_min, area_max, price_min, price_max,
  orientation, house_structure

V2.2 #1 新增:
  sale_points (本地 MongoDB $all)
  objective_features (辞典 4 步过滤)
  decoration (辞典)
  heating_type (辞典)
  bld_year_start / end (辞典楼龄范围)
  community_id (按社区精确过滤)

排序:
  sort = default | latest | price_asc | price_desc | unit_price_asc | area_desc
```

完整接口表查 Swagger,本档不重复 V8.8 已记录的部分。

---

## 八、模块完成度盘点(Day 31 末)

| 模块 | 完成度 | V9.0 关键增量 | 待办 |
|---|---|---|---|
| **模块一 注册登录** | 95% | 全局断网检测 + 登录页 FormState + field 红 * + 密码登录 + **会员费机制(开关/过期只读/后台开通,真机待验)** | 微信登录 / 生物识别 / 设备信任 / Web 会员后台 / 自助续费支付 |
| **模块二 房源管理** | 95% | 4 营销字段(sale_points 等)+ 14 obj_features + house_structure + 户型图 + 调价时间线 | COS 迁移 / 即将上市 / 撤牌 / 暂停 |
| **模块三 共享房源库** | 95% | 5 类新筛选 + 6 排序 + 卡片视觉 v2 + community_id 过滤 + qna_count 角标 | 高德地图 / CMA / 关注小区 |
| **模块四 带客协作 + Q&A** | 92% | Q&A 问答完整(4 API + UI + 待办) + customer_id 必填(WIP) | 7 天过期定时任务 / 批量审批 / 实时推送 |
| **模块五 交易留痕** | 90% | LA 视角带看汇总 + 成交双向待办 + 反作弊基石视觉化(MlsEncryptedPanel) | LA 催促 / 14d 回退 / 30d 修正 / 争议仲裁 / bonus 严格快照 |
| **模块六 Web 管理后台** | 0% | — | 全部(V3 起手) |
| **模块七 推送消息** | 0% | — | 极光接入 / WebSocket / FCM |

**整体进度**:V2.1(Day 25 末)→ V2.2 #1 完工(Day 32)→ 视觉规范 V2 全接入(Day 31)→ V6 大屏(Day 31)→ V3 段 1.1 起手(Day 36 实际日期,见战绩)

---

## 九、Day 26-31 战绩

### 9.1 阶段分布(~90 commit)

| 阶段 | commit 数 | 主要产出 |
|---|---|---|
| **A. 主题重构** | ~20 | AppTheme → Mls token 全工程迁移(800+ → 0) |
| **B. Design System V2** | ~10 | v2.0 双主色 + 8 核心组件 + Hero/Gold/Surface |
| **C. V2.2 #1 社区/筛选/详情** | ~18 | 18 communities 字段 + 4 listings 字段 + 5 筛选 + 6-section + 测试 203 |
| **D. 安全/UI 修复** | ~10 | isOwner 守卫 4 处 + 详情页 5 字段脱敏 + 圆角/字号 3 轮迁移 |
| **E. Q&A + Tx Day 37** | ~12 | Q&A 后端模型 + 4 API + Flutter UI + 成交双向待办 + 12 单测 |
| **F. V6 Dashboard** | ~9 | 6 图表组件 + dashboard_v6.py 后端聚合 + 整页接入 |
| **G. V3 段 1.1**(中间穿插) | ~6 | db_router.py + 数据迁移 mls → mls_zhangjiakou + 4 单测 |

### 9.2 关键决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 视觉规范 V1 vs V2 | V2(双主色 + Lucide + Surface 分层) | V1 SVG 过于平面,V2 更"立体科技商务"贴合 B 端 |
| `halls` 字段保留 vs 删 | 删,改 `house_structure`(6 枚举) | 户型结构维度比"厅数"更产品化 |
| `objective_features` 7 vs 14 | 14(加厅带阳台/卧室阳台/明厨等) | 张家口本地经纪人反馈 7 不够细 |
| 多区域隔离时机 | V3 段 1.1 立即起手(不等 V2.2 全完) | 单库到多库迁移痛苦,趁数据少做 |
| Q&A 脱敏粒度 | LA 全名 + BA "李*" | 平衡识别需求与隐私 |
| customer_id 可选 vs 必填 | 必填(V2.1 起强制,Day 31 在改) | 旧扁平字段已无意义,全走客户档案 |
| Dashboard V6 卡片数 | 7 卡(原 5 卡) | 加信誉等级(卡 6 上下两层) + 荣誉(卡 7) |

### 9.3 commit 总数

```
Day 26-31:  ~90 commit · 6 大阶段 · 视觉重做 + V2.2 #1 完工 + V6 大屏 + Q&A + V3 起手
```

详细 commit 链查 git log:`git log efbe291..393dfae --oneline`。

---

## 十、坑账总集

### 10.1 V8.x 坑 1-59(承袭 V8.8,详情查 V8.8)

V8.8 §十 已完整记录 1-59,V9.0 不重复正文,仅保留**索引**:

| 类别 | 坑号 | 主题 |
|---|---|---|
| A. 环境配置 | 13-18 | Windows / Android SDK / Gradle / VPN / 镜像 |
| B. Dart/Flutter 语言陷阱 | 25, 27, 32 | enum / Spacer / IntrinsicHeight |
| C. Pydantic/FastAPI | 28 | silent discard 字段 |
| D. VS Code 工作流 | 26 | 大文件替换 |
| E. 权限/Manifest | 29 | url_launcher queries |
| F. 跨语言类型系统 | 30 | ObjectId vs str |
| G. UI 状态管理 | 11, 31 | FutureBuilder / setState |
| H. Day 22 推断坑(已注销) | 38-48 | V8.7 推断 11 个,真撞 2 个 |
| I. Day 23-25 实录 | 49-59 | 真机回归 + V2.1 打磨 |

特别重点查回:
- **坑 11**(Flutter 异步标准解法,铁律 5 来源)
- **坑 38**(MLS 调辞典三层根因 — graceful degrade 不能在用户字段缺失时启用)
- **坑 49**(filter matches 漏 isActive 守卫)

### 10.2 Day 26-31 新增坑账(60-62)

#### 坑 60 · V2.2 #1 撞坑总集

详见 `docs/V2.2_1_技术债.md`(56 行),撞坑由 Web Claude 整理为 3 条(60-62 占位,具体细分见原文):

1. **辞典 batch endpoint codes 上限未定**——大量 community_id 批量查时,辞典侧 V2.1 #15 已预留但未上限,V3 注意
2. **测试 mock 路径适配**——`listings.py` → `services/listing_filter.py` 拆分后,旧测试 mock 路径 `_batch_fetch_communities_by_name` 需迁到 `batch_fetch_communities_by_name`(下划线移除)
3. **字段 always-accept 语义边界**——辞典 V2.2 #1 起 claims 改 always-accept,旧 spec 中"force=true / no-force"描述已删,辞典 always-accept 为准

#### 坑 61 · MlsPulse 在固定大小容器内 overflow

**症状**:`MlsProgressStepper` 当前节点 pulse 动画在父容器 nodeSize=12 的圆点上,maxRadius=20 时报 8px RIGHT OVERFLOW。

**根因**:`MlsPulse` 子组件向外扩张,父容器未给"溢出可见"许可,Flutter 默认 ClipRect 截断。

**修复**(Day 31,工作树未提交 diff 2):
```dart
node = SizedBox(
  width: nodeSize, height: nodeSize,
  child: ClipRect(
    clipBehavior: Clip.none,  // 关键
    child: OverflowBox(
      maxWidth: double.infinity, maxHeight: double.infinity,
      child: MlsPulse(pulseColor: currentColor, maxRadius: nodeSize + 18, child: core),
    ),
  ),
);
```

**通用教训**:`MlsPulse` 在任何固定大小容器内使用,**必须** SizedBox + ClipRect(clipBehavior: Clip.none) + OverflowBox 三件套。

#### 坑 62 · V6 卡 7 MedalGrid 真机 7px RIGHT OVERFLOW(WIP)

**症状**:V6 数据大屏卡 7 荣誉等级,真机 debug 模式报 7px RIGHT OVERFLOW,Release 不显示。maxWidth 实测 322px,2 行 Row × 4 Expanded + 圆圈 44px + border 1px,理论够。

**已尝试**:Column 上下两层(卡 6 同款解法,卡 6 已修)、boxShadow 全删、border 1px

**待诊断**:DevTools widget inspector 看外层 MlsCard / `_darkCard` 是否给 padding/decoration 偷掉宽度

**优先级**:🟡 中,纯视觉,Release 不显示。Day 32 可见诊断。

### 10.3 已知技术债(V9.0 重排)

#### 🔴 高优先级

1. **COS 对象存储迁移**(承袭 V8.x)
   - 照片 base64 存 MongoDB,50 户内临时方案
   - 先决:申请腾讯/阿里/七牛 COS 账号

2. **Pydantic 校验补强**(承袭 V8.x)
   - `price_wan` 允许负数 / 姓名 50 字 / 备注 1000 字均通过
   - 用户可编辑字段必须加 Pydantic validator

3. **实时推送(WebSocket / 极光)**
   - 当前协作详情页 pop 后自动刷新是部分修
   - V8.4 起持续登债

#### 🟡 中优先级

4. 带客申请 7 天过期定时任务(APScheduler,不依赖推送)
5. 成交日期 vs 带看时间严格比较 bug
6. `initiate_transaction` 未给 `bonus_yuan` 拍快照
7. 直接带看 listing 状态守卫扩展(`transaction_ongoing` 该入白名单)
8. 房源表单缺奖金输入字段
9. flutter analyze 现状:0 error, 3 warning, ~30 info(pre-existing)

#### 🟢 低优先级(本周最小可行包,55min,见 `docs/optimization_report.md`)

10. pre-commit hook:`flutter analyze`
11. `.env` 统一管理
12. `docs/README.md` 文档版本墙索引

#### 🟣 V3 范围(承袭 V8.8)

13. retry scheduler 实施(辞典 sink 异步重试,V8.8 §九.5)
14. Web 管理后台(模块六全部)
15. 推送服务接入(模块七全部)

---

## 十一、当前阶段(Day 31 末,2026-05-14)

### 11.1 工作树未提交(Day 32 起手必清)

3 个文件改了未提交:

1. **`collaboration_list_screen.dart`** — `ProgressTracker` → `MlsProgressStepper`(6 步)迁移
2. **`mls_progress_stepper.dart`** — 坑 61 修复(脉冲动画 ClipRect + OverflowBox 包)
3. **`backend/showing_requests.py`** — `customer_id` 从可选改必填 + 合并校验

未跟踪 3 项:

- `docs/_interim/`(2 个 md,可能是 Web Claude 出的中间产物)
- `docs/optimization_report.md`(优化优先级矩阵,Day 31 写的)
- `start_dev.cmd`(起服务老三样脚本)

### 11.2 进行中任务

| 任务 | 状态 | 下一步 |
|---|---|---|
| Dashboard V6 整页接入 | ✅ Done(393dfae) | — |
| 卡 6 信誉等级 overflow | ✅ Done(改 Column 上下两层) | — |
| 卡 7 MedalGrid 真机 7px overflow | 🟡 WIP | DevTools widget inspector 看外层 MlsCard 是否偷宽度 |
| customer_id 必填 方案 A | 🔵 步骤 1 已 Done(后端 Pydantic + 校验) | 步骤 2:前端 UI 强制 + 步骤 3:历史回填脚本 dry-run |

### 11.3 Day 32 起手锚点

```
接 Day 31 V6 大屏 + V2.2 #1 完工,工程 393dfae clean,本地 = origin/main。
工作树未提交 3 项需先收尾(MlsProgressStepper 迁移 + 坑 61 修复 + customer_id 必填后端)。
今日待办:
  1. 工作树 3 项收尾 commit(20min)
  2. 卡 7 overflow DevTools 诊断(30min)
  3. customer_id 必填 步骤 2(前端 UI)+ 步骤 3(历史回填 dry-run)(1h)
  4. V2.2 #2 / V3 段 1.2 路线决策
长期档 V9.0 已落,接力锚点。
```

### 11.4 V2.2 / V3 路线候选(待 Day 32 拍)

**V2.2 后续候选**:
- V2.2 #6:房源照片真上传(COS 对接)— 高优先级
- V2.2 #7:协作 Tab 重构(进度条卡 v2)— 中
- V2.2 #8:实时推送(WebSocket)— 高,但工程量大

**V3 路线候选**:
- 段 1.2:多城路由完整接通(`get_current_city` dependency 全 endpoint 覆盖)
- 段 2:Web 管理后台(Vue3,模块六)
- 段 3:推送服务(极光,模块七)

---

## 十二、Day 26-31 关键决策与教训

### 12.1 视觉规范重做的教训

V1 → V2 跨度大(单色 → 双主色 + Lucide + Surface 分层 + Gradient),全工程 800+ 引用迁移分 10 批次。

**有效做法**:
- AppTheme 兼容别名(c690b1f)救场 28 文件编译
- 批次化迁移(批次 1-5),每批一个 commit + 真机回归
- token 层先定,组件层再做(批次 1-3)
- `STYLE_GUIDE.md` 锁定规约后才大规模铺开

**反面教训**:
- 视觉重做与 V2.2 #1 业务功能并行,中间一度 800+ 引用并存,几个 commit 出现 unused_import warning(批次 4A.2.c 系列)
- 主题切换初期(`bc9907b`)未把 AppTheme 直接删,留了 Header 仍走旧色的尾巴

### 12.2 V2.2 #1 的"双流程提交"模式

挂牌 / 编辑页加客观字段时,统一采用"双流程提交":

```
Step A: POST/PATCH /listings 带营销字段
Step B: POST /listings/{id}/sync-physical 带物理字段(经辞典裁决)
```

这套模式延续 V2.1 段 7.5 的"黄条 + 一键同步"约定,V2.2 #1 把可选客观字段(`objective_features` / `decoration`)纳入同流程。**核心:物理字段必经辞典裁决,不直接 PATCH**(Bug B 教训,V8.8 §十.4)。

### 12.3 反作弊基石视觉化

`MlsEncryptedPanel` 组件(批次 4C.3,9eaf92a)将"双方填价比对"机制视觉化:

- pending 状态:字段遮罩 ▓▓▓ + 3s 扫描线动画 + SECURED 徽章 + 富文本说明"对方填报中,完成前互不可见"
- confirmed 状态:正常展示数值

**意义**:让用户**看到**反作弊机制在工作,而不是只在后端默默 mask。

---

## 十三、关键文件索引(Day 31 末)

### 13.1 后端核心

```
backend/
├── main.py                       1484 行,~60 endpoint 入口
├── dashboard_v6.py               ⭐ 208 行,V6 大屏 5 卡聚合
├── db_router.py                  ⭐ V3 段 1.1,get_db(city)
├── listings.py                   ~450 行(V2.2 拆分后)
├── showing_requests.py           带客申请(WIP customer_id 必填)
├── showings.py
├── transactions.py
├── settlements.py
├── communities.py                18 字段 schema
├── customers.py
├── collaborations.py
├── qna.py                        ⭐ Q&A 4 endpoint
├── scheduler.py
├── services/
│   ├── listing_filter.py        batch + passes_dict_filters
│   └── listing_enrich.py        enrich_from_dictionary
├── const/sale_points.py          21 预设 + 4 自定义槽
├── utils/
│   ├── anonymize.py             Q&A 脱敏
│   └── collaboration_status.py  is_collaboration_unlocked
└── tests/                        116 tests
```

### 13.2 前端核心

```
app/mls_app/lib/
├── config/api_config.dart        ⚠️ baseUrl
├── theme/                        6 个 Mls token 文件
├── widgets/mls/                  21 个 Mls 组件
├── screens/
│   ├── dashboard_screen.dart           ⭐ V6 大屏 ~470 行
│   ├── community_detail_screen.dart    ⭐ V2.2 #1
│   ├── my_questions_screen.dart        ⭐ V2.2 #2
│   ├── qna_list_screen.dart            ⭐ V2.2 #2
│   ├── listing_detail_screen.dart      ⭐ 6-section 权限分层
│   ├── listing_shared_screen.dart      ⭐ 5 类筛选
│   └── ...
├── services/
│   ├── dashboard_service.dart    ⭐ v6() 方法
│   ├── qna_service.dart          ⭐
│   └── ...
├── router/app_router.dart
└── main.dart                     (MlsTheme.light 入口)
```

### 13.3 文档(`docs/`)

**当前 ground truth**(Day 31 末):

| 文档 | 行数 | 用途 |
|---|---|---|
| **MLS交接文档V9_0.md** | (本档) | 长期档,新会话开工密码 |
| CLAUDE.md V1.2 | 683 | ⚠️ 已过期(停 Day 17),V2.0 待写 |
| decisions_v10.md | 641 | 产品决策汇总,业务层 ground truth |
| STYLE_GUIDE.md | 66 | 视觉规约 + 派工模板 |
| DESIGN_SYSTEM_v2.md | 256 | 设计系统 v2.0 完整规范 |
| optimization_report.md | 163 | 本周优化优先级矩阵 |

**V2.2 #1 实施档**(Day 32 完工):

| 文档 | 行数 | 用途 |
|---|---|---|
| V2.2_1_实施总结.md | 97 | 18 commit 链 + 字段变更表 + 接口变更表 + 撞坑(60-62)+ 预算 |
| V2.2_1_数据流图.md | 136 | 5 条核心流程 mermaid |
| V2.2_1_测试覆盖.md | 110 | 203 tests 盘点 + 未覆盖真机排查清单 |
| V2.2_1_技术债.md | 56 | 坑 60-62 详情 + 代码异味 + analyze 36 issues |

**bridge PoC**(Day 30 调研):

| 文档 | 行数 | 用途 |
|---|---|---|
| bridge_poc_feasibility.md | 141 | Claude Code 非交互式调用验证 |
| bridge_poc_cost_report.md | 123 | 成本推算 ~$400-1200/周 |

**模块 spec**(V10 设计稿,代码实现度查 §八):

```
module_1_auth.md
module_2_listing.md
module_3_shared.md
module_4_collab.md
module_5_transaction.md
module_6_admin.md
module_7_push.md
```

**V2 历史档**:

| 文档 | 用途 |
|---|---|
| V2_flutter_analyze_report.md | flutter analyze 报告 |
| V2_backend_smoke_test_report.md | 46 case / 60 endpoint 冒烟 |
| V2.1_listing_data_audit.md | 10 条 listing 健康度 |
| mls_visual_v1_progress.md | V1 接入进度看板(已完工) |
| skill_candidates.md | skill 候选清单 |

**历史长期档(作废保留)**:

```
MLS交接文档V8_8.md  Day 25 末
MLS交接文档V8_7.md  Day 23 末
V8_2.md / V8_3.md / v8_5.md / v8_6.md  早期阶段
MLS_App_IA设计文档V2.md  IA 设计稿
```

---

## 十四、命令速查

### 14.1 起服务老三样

```cmd
REM 查 IP(每次开机必做)
ipconfig

REM 起 MLS 后端(8000)
cd C:\projects\mls\backend && venv\Scripts\activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000

REM 起辞典后端(8001)
cd C:\projects\property-dictionary\backend && venv\Scripts\activate && uvicorn main:app --reload --host 0.0.0.0 --port 8001

REM 起前端
cd C:\projects\mls\app\mls_app && flutter run
```

Swagger UI:`http://<ip>:8000/docs`(MLS)/ `:8001/docs`(辞典)

### 14.2 鉴权 + curl 调试

```cmd
REM 1. 发验证码
curl -X POST http://localhost:8000/api/v1/auth/send-sms-code ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13912345678\"}"

REM 2. 登录(开发态固定 123456)
curl -X POST http://localhost:8000/api/v1/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13912345678\",\"code\":\"123456\"}"

REM 3. 用 token 调接口
curl http://localhost:8000/api/v1/listings/mine ^
  -H "Authorization: Bearer <access_token>"

REM 4. V6 大屏接口(Day 31 新增)
curl http://localhost:8000/api/v1/dashboard/v6 ^
  -H "Authorization: Bearer <access_token>"
```

### 14.3 archive 备份

```cmd
mkdir C:\projects\archive
echo archive/ >> C:\projects\.gitignore

mongodump --db mls_zhangjiakou --out C:\projects\archive\mls_zjk_<日期>
mongodump --db property_dict --out C:\projects\archive\dict_<日期>
```

⚠️ V3 段 1.1 起,MLS 数据库名是 `mls_zhangjiakou`(不是 `mls`)。

### 14.4 reset 命令

```cmd
REM 双侧业务清空(保字典)
cd C:\projects\mls\backend
venv\Scripts\activate
python scripts\reset_to_v2_1.py

cd C:\projects\property-dictionary\backend
venv\Scripts\activate
python scripts\reset_to_v2_1.py

REM Java 进程杀干净(坑 16)
taskkill /F /IM java.exe

REM Flutter 缓存清
flutter clean
flutter pub get
```

### 14.5 测试

```cmd
REM MLS 后端 pytest(116 tests)
cd C:\projects\mls\backend && venv\Scripts\activate && pytest

REM 辞典后端 pytest(87 tests)
cd C:\projects\property-dictionary\backend && venv\Scripts\activate && pytest

REM Flutter analyze
cd C:\projects\mls\app\mls_app && flutter analyze
```

### 14.6 git 速查

```cmd
REM 看最近提交
git log --oneline -20

REM 看未提交改动
git status
git diff <file>

REM 看 V8.8 → V9.0 增量(本档覆盖)
git log efbe291..393dfae --oneline
```

---

## 十五、端口速查

| 服务 | 端口 |
|---|---|
| MLS 后端 | 8000 |
| 辞典后端 | 8001 |
| MongoDB | 27017(默认) |
| Flutter DevTools | 9100(默认) |

---

## 十六、V9.0 收档总结

### 16.1 Day 26-31 全景战报

```
═══════════════════════════════════════════════════════════
                  V9.0 阶段完工节点
       Day 25 末 efbe291 → Day 31 末 393dfae · ~90 commit
═══════════════════════════════════════════════════════════

阶段 A · 主题重构 (~20 commit)
  AppTheme → Mls token 全工程迁移
  800+ 引用 → 0,4 个旧文件删除
  Card → MlsCard 批量(43 处 19 文件)
  STYLE_GUIDE.md 锁定规约

阶段 B · Design System V2 (~10 commit)
  双主色 + Surface 分层 + Lucide 图标
  工作台 Gradient Hero + Gold 奖金卡 v2
  共享库视觉重做 + 真实地产 App 风格

阶段 C · V2.2 #1 完工 (~18 commit)
  communities 18 字段 + properties 2 字段(obj+decor)
  listings 4 营销字段 + 删 remarks
  共享库 5 类筛选 + 6 排序 + community_id 过滤
  详情页 6-section 权限分层 + 社区迷你卡
  CommunityDetailScreen + 3-tab + 房源动态 + 同居室
  辞典 always-accept + batch endpoint
  测试 116 + 87 = 203

阶段 D · 安全/UI 修复 (~10 commit)
  isOwner 守卫 4 处 + 5 字段补脱敏
  全局断网检测 + 登录页 FormState
  圆角/字号/颜色 3 轮迁移(80+ 文件)
  halls → house_structure 6 枚举

阶段 E · Q&A + Tx Day 37 (~12 commit)
  Q&A 后端 + 4 API + 详情页 section
  脱敏(LA 全名 / BA 李*) + 限流 + role 双保险
  my-questions 汇总页 + 工作台待办
  成交双向待办(LA + BA filter 合并)

阶段 F · V6 数据大屏 (~9 commit)
  6 图表组件(DualBar/DualLine/Funnel/Donut/MedalGrid/MedalInline)
  dashboard_v6.py 后端聚合(5 卡)
  整页 FutureBuilder 三态 + 7 卡接 6 组件

阶段 G · V3 段 1.1 多城多库(中间穿插)
  db_router.py + get_db(city) dependency
  数据迁移 mls → mls_zhangjiakou(14 集合 54 文档)
  4 单测 mock 模式 + 双库 count 对比通过

═══════════════════════════════════════════════════════════
   6 大阶段 · ~10 天 · ~90 commit · V2.1 → V2.2 #1 + V3 段 1.1 起手
═══════════════════════════════════════════════════════════
```

### 16.2 Day 32 锚点

```
锚点:
  ☐ 工作树 3 项收尾 commit(MlsProgressStepper / 坑 61 / customer_id 必填后端)
  ☐ 卡 7 MedalGrid overflow DevTools 诊断
  ☐ customer_id 必填 步骤 2 + 3(前端 UI + 历史回填)
  ☐ V2.2 / V3 路线决策(候选见 §11.4)

技术债优先级:
  🔴 COS 迁移 / Pydantic 校验 / 实时推送
  🟡 7d 过期定时任务 / bonus 快照 / 直接带看状态守卫
  🟢 pre-commit hook / .env 统一 / docs README 索引

商业准备(未启动):
  ☐ 种子用户 2-3 位(LA + BA 混合)
  ☐ 月费/年费定价
  ☐ App 安装包 release build
  ☐ 真机服务器选择
  ☐ 短信服务真接
  ☐ 用户协议 / 隐私政策 / ICP 备案
```

### 16.3 待写文档

V9.0 落档后,Web Claude 接下来要写(按磊优先级):

1. **CLAUDE.md V2.0**——接替 V1.2,给 Claude Code 读的项目工作手册
2. **项目核心描述系列**(分多份)——给任何新 Claude 会话挂的项目密码:
   - 产品本体描述(是什么/给谁用/不做什么)
   - 商业模式与定位
   - 核心机制与反作弊
   - 技术架构与铁律
   - 协作模式(三方分工)

---

**V9.0 写作时长**:Day 32 写作日 Web Claude ~3h(信息密度高,代码反推 + V8.8 体例承袭)
**V9.1 / V10.0 触发条件**:Day 32 工作树收尾后,V2.2 #2 / V3 段 1.2 决策落地后再决定增量 or 重写
**承接交接档**:V8.8(已作废保留),CLAUDE.md V1.2(待 V2.0 替换)

---

> 本档由磊 + Claude Opus 4.7(Web 端)在原始档案丢失后从代码反推重建。
> "机制服务于信任的演化" —— MLS 张家口实例,V2.2 #1 完工,V3 段 1.1 起手。
