# MLS 交接文档 V8.7(长期档 · 完整重写版)

> **更新时间**:Day 23 末(2026-05-09)
> **关系**:V8.6 整档作废,V8.7 自包含,无需回看 V8.6 即可上手
> **承接**:V8.6 长期档(Day 21 末)+ Day 22 11 commit + Day 23 1 commit
> **本档主要变化**:
> - V8.6 §五 数据归属表 → 段 7.2-7.5 落地后**字段级重写**(physical 6 已物理删除,property_code 已冗余双写)
> - V8.6 §六 辞典 4 层机制 → 真机回归后细节微调
> - V8.6 §八 段 7 实施蓝图 → **改为段 7 进度盘点**(7.1-7.6 全部完成,7.7 待 Day 24)
> - V8.6 §十 坑位档 → **重写为坑账总集 1-49**,Day 21-22 推断式 11 个登债 + Day 23 坑 49 实录
> - **新增 §七 API 接口表**(对照 Swagger 实测全量路由)
> - **新增 §十一 技术债 candidates**(坑 50-52 已暴露未还)
> **下次开工锚点**:Day 24 · V2.1 #15 段 7.7 · 全套数据清空 + 真机回归(0.5-1d 收 V2.1)

---

## 一、版本与文档定位

### 1.1 V8.7 是什么

V8.7 是 MLS 项目的**长期档**——不记每日操作步骤,记需要长期承袭的:

- 项目基本信息(人 / 路径 / 栈 / 账号)
- 产品本体定义(角色 / 商业模式 / 核心机制)
- 架构铁律(违反则动地基)
- 数据归属字段表(段 7 后定型)
- 辞典 4 层机制
- API 接口实测全表
- 模块完成度盘点
- 坑账(诊断成本沉淀,避免重蹈)
- 工作流铁律 + 命令速查

**不属于本档的**:每日 commit 日志、单步操作步骤、模块详细 spec(看模块一到模块七 .md)、临时决策的细节。

### 1.2 V8.7 vs V8.6

V8.6 在 Day 21 末定档,当时段 7 还没起手。Day 22 一天打掉段 7.1-7.6 共 6 个子段(11 commit),Day 23 把段 7.5 的真机回归收尾(1 commit)。这意味着:

- V8.6 §五 数据归属表里的 `property_id 引用辞典(property_code 或 ObjectId,段 7 拍)` 这种"待拍"项目 —— 段 7.2 已经拍了,V8.7 落最终值
- V8.6 §六 辞典 4 层机制的细节 —— 经过 Day 22-23 真机验证有微调
- V8.6 §十 "Day 21 0 新坑" —— Day 22-23 共暴露 12 个新坑(38-49),V8.7 全部入档

V8.6 整档作废的实际含义:**V8.6 不再是当前 ground truth**,但作为历史档保留(命名 V8.6,不删)。新会话开工密码只需挂 V8.7。

### 1.3 适用场景

| 场景 | 操作 |
|---|---|
| 新会话开工 | 把 V8.7 + 当天起手任务挂进上下文 |
| 临时上下文丢失 | 把 V8.7 §九 战绩 + §八 模块完成度 贴回去 |
| 决策依据回查 | 看 §四 铁律 + §五 数据归属 + §九 战绩里的"关键决策" |
| 撞坑前自检 | 搜 §十 坑账,90% 已知坑能避开 |
| API 联调 | §七 接口表(对照 Swagger 实测) |
| 起新机器 | §二 项目基本信息 + §十四 命令速查 |

---

## 二、人 / 项目基本信息

### 2.1 人

**磊**:创始人 + 唯一开发者。张家口本地。Windows 11 笔记本(24H2)。**非技术背景**——通过与 Claude 协作开发,已建立对 Flutter / FastAPI / MongoDB / Git 的工作熟悉度,能独立完成"读懂报错 → 复述给 Claude → 验证 fix → commit push"全流程。

**操作偏好**:
- 终端**只用 cmd**,不用 PowerShell(脚本路径分隔、转义规则差异大)
- VS Code 是主 IDE,Android Studio **只用 SDK 管理**,不用其代码编辑器
- 真机调试:USB 直连华为 NOH AL00,不依赖 emulator

### 2.2 项目结构

```
C:\projects\                      <-- monorepo 根
├── mls\                          <-- MLS 主应用
│   ├── backend\                  <-- FastAPI 后端,8000 端口
│   │   ├── venv\                 <-- Python 3.11.15 venv
│   │   ├── main.py               <-- app 入口 + 路由注册
│   │   ├── routes\               <-- 业务 endpoint
│   │   ├── services\             <-- 含 dictionary_client.py(段 7.1)
│   │   ├── models\
│   │   ├── schemas\
│   │   └── scripts\reset_to_v2_1.py  <-- 段 7.7 待写
│   └── app\mls_app\              <-- Flutter app
│       ├── lib\
│       │   ├── screens\
│       │   ├── services\         <-- 含 api_client.dart
│       │   ├── models\
│       │   └── widgets\
│       └── android\
├── property-dictionary\          <-- 楼盘辞典服务(独立)
│   └── backend\                  <-- FastAPI 后端,8001 端口
│       ├── venv\                 <-- Python 3.11.9 venv(注意 mls 是 3.11.15)
│       └── ...
└── archive\                      <-- 测试数据备份(.gitignore,不入仓)
    └── mls_pre_v2_1_20260508\    <-- Day 23 准备 / Day 24 全清前 mongodump
```

**MongoDB 数据目录**:`C:\data\db\`(本地 mongod 启动)

### 2.3 技术栈

**MLS 后端**:
- Python 3.11.15
- FastAPI(uvicorn 起在 :8000,**所有路由前缀 `/api/v1/`** —— 这是 Day 23 实测确认的,V8.6 接口表里漏了这个前缀,导致 curl 多走一轮 404)
- MongoDB 8.2 Community(本地)
- fakeredis(开发态模拟 Redis,生产前必须切真 Redis)
- APScheduler(7 天到期定时任务,in-process,不依赖外部 worker)
- JWT(access 2h / refresh 30d,`flutter_secure_storage` 客户端加密存)
- Pydantic v2(注意 v2 的 strict 默认行为,见坑 28)

**辞典后端**(独立服务):
- Python 3.11.9 + FastAPI 0.115
- MongoDB 8.2(独立 db `property_dict`)
- pytest(74 条单测全 pass · Day 21 已建立基线)
- 端口 8001,所有路由前缀 `/v1/`

**MLS App 前端**:
- Flutter 3.41.7 / Dart
- Android SDK API 36.1
- 关键依赖:dio / hive / flutter_secure_storage / image_picker / image_compress / go_router / amap_flutter_map / cached_network_image / url_launcher / permission_handler / photo_view / connectivity_plus
- **不使用 Riverpod 的部分**:Day 22 段 7.5 后部分 screen 改用 FutureBuilder 直接驱动,与 V8.6 §一里的 Riverpod 假设有偏

**镜像源**(永久配置,不改慎动):
- Tencent cloud:Gradle 包 → `gradle-wrapper.properties`
- Aliyun:Maven 仓库 → `build.gradle.kts` + `settings.gradle.kts`
- VPN 必须用 TUN / 增强模式,cmd / Gradle 流量才能走代理(坑 17)

### 2.4 测试账号

| 账号 | 手机号 | 角色 | agent_id (ObjectId) | 备注 |
|---|---|---|---|---|
| 张三 | 13912345678 | LA(挂牌) | `69e45ec6e52ec020aa924065` | Day 23 实测 9 条 listing |
| 李红 | 13200132000 | BA(带客) | (Day 24 全清前不锚定) | 协作链 BA 端 |

**短信验证码**:开发态 fakeredis 模式下后端会接受 `123456`(一次性,用过即失效,要重新调 `/auth/send-sms-code` 才能拿新的)。生产前**必须切真 SMS 服务**,把这个固定值移除。

### 2.5 GitHub 远端

- 仓库:`git@github.com:leelei-hub/mls.git`(monorepo)
- 主分支:`main`
- 推送策略:granular commit,每个独立改动一个 commit,detailed message。push 频率高,本地几乎一直 = origin/main

### 2.6 当前 IP / Swagger UI

每次 Windows 重启后 IP 会变(局域网 DHCP),`ipconfig` 查当前 IPv4。

- MLS Swagger:`http://<ip>:8000/docs`(实战中本机用 `localhost:8000` 也行,但真机回归必须用局域网 IP)
- 辞典 Swagger:`http://<ip>:8001/docs`

**真机回归坑**(候选坑 51 备注):真机连不到 PC 的 localhost(localhost 是真机自己),App 端 baseUrl 必须是 PC 局域网 IP `192.168.x.x:8000`。Day 23 段 7.5 真机回归时这一步已配好,但每次 IP 变了要改。

---

## 三、产品本体与商业模型

### 3.1 一句话定义

**MLS = 张家口二手房经纪人协作系统**。B2B SaaS,会员费制,服务于本地中介经纪人之间的房源共享 + 带客协作 + 反作弊交易留痕。

### 3.2 名称与边界

- 中文名:**张家口二手房经纪人协作系统**
- 英文缩写:MLS(借用美国 Multiple Listing Service 的概念,但商业模式不同)
- **覆盖城市**:张家口(单城起家)
- **覆盖业态**:二手房(新房 / 商铺 / 写字楼后续考虑)
- **不覆盖**:C 端用户(经纪人之间的工具,不直接面向购房者)

### 3.3 角色定义

```
经纪人(agent)─┬─ LA(Listing Agent / 挂牌经纪人)── 持有房源,赚 LA 费 + 合作奖金
              └─ BA(Buyer Agent / 买方经纪人)── 带客户,赚 BA 费 + 合作奖金

同一个经纪人可同时是 LA 和 BA(自促成交场景:自己挂的房自己带客成交)。

门店账号(broker)── 老板账号,既具备完整经纪人身份,又额外管理下属经纪人。
                     角色切换器(门店管理 / 个人经纪人)在工作台顶部。
```

### 3.4 商业模型

**会员费制**,**不抽成**。这是核心商业决策,与传统中介平台不同:

| 维度 | 传统平台(贝壳类) | MLS |
|---|---|---|
| 收入来源 | 抽成(每笔成交平台拿走 X%) | 会员费(经纪人按月/年付) |
| 利益对齐 | 平台希望经纪人多成交 | 平台希望经纪人留得住 |
| 经纪人感知 | 平台是分蛋糕的 | 平台是工具 |
| 数据归属 | 平台拿走 | 经纪人共享但归属本地 |

**会员费收谁**:
- 个人经纪人(独立或挂靠门店的)
- 门店账号(broker 身份的)
- 不向购房者收费

### 3.5 核心理念

**机制服务于信任的演化**。

平台不是中立工具,是信任机制的载体。经纪人之间的合作天然有博弈(怕被截客 / 怕被压价 / 怕分赃不均),平台通过机制设计让"诚实合作"是 dominant strategy:

- 共享房源库 + 身份隐藏 → 防截客
- 带客申请双向通过制 + 失败原因留档 → 防滥用
- 反作弊三分支(LA 独立填价 + 比对) → 防成交压价
- audit_log 全留痕 → 事后追溯

### 3.6 核心机制(用户旅程)

```
LA 挂牌 → 共享库可见 → BA 申请带客 → LA 批准 → BA 带看 →
LA 确认带看 → BA 发起成交 → LA 独立填价 → 系统比对 →
匹配则 confirmed → 进结算 → 双方拿合作奖金
                               ↓
                            不匹配则进争议处理(后台介入)
```

5 个核心节点 + 反作弊比对,V2 已全部跑通:

```
节点 ①:listing(挂牌)
节点 ②:showing_request(带客申请)
节点 ③:showing(带看)
节点 ④:transaction(成交,反作弊三分支:接受 / 价不符进争议 / 时间不符进争议)
节点 ⑤:settlement(结算)
```

V2.1 在此之上叠加楼盘辞典系统(资产层),V2.1 #15 段 7 是 MLS 接入辞典的双侧改造。

### 3.7 商业层级:辞典 vs MLS(资产 vs 产品)

V8.6 §三 第一次明确这一关系,V8.7 重申:

```
楼盘辞典(独占数字资产)            ← 数据飞轮,越用越值钱
    ↓ HTTP REST + X-API-Key
MLS 张家口实例(可被接入的应用产品)   ← 单城单实例
MLS 保定实例(未来扩张)             ← 复用同一辞典
MLS 廊坊实例(未来扩张)             ← 复用同一辞典
第三方系统(未来生态)               ← 复用同一辞典
```

辞典是**资产**(独立服务、独立 db、多租户预留、API Key 鉴权、city_scope 隔离)。MLS 是**产品**(单城单公司单 db,会员费制业务流)。两者通过 HTTP REST 通信,**不共享 venv / db / 端口 / 进程**(铁律 1)。

**V2.1 阶段实施**:辞典只签 1 个 API Key 给 MLS 张家口实例用,所有多租户机制就位(schema + 中间件)但实际只 1 个用户(磊本人)+ 1 个调用方(MLS)。未来扩张是改 JSON / 加 user record 的事,不是写代码。

---

## 四、6 条架构铁律(V8.7 承袭并经 Day 22-23 验证)

> 这 6 条是辞典 + MLS 的**根**。任何后续改造,先确认不违反;违反就是动地基。
> Day 22-23 段 7 接入实施全程,这 6 条无破例。

### 铁律 1 · 物理隔离

辞典与 MLS 是**两个独立的服务**,不共享 venv / db / 端口 / 进程。

- venv:`property-dictionary\backend\venv\`(3.11.9) vs `mls\backend\venv\`(3.11.15)独立
- db:`property_dict` vs `mls` 独立
- 端口:8001 vs 8000
- 通信:仅通过 HTTP REST,不允许直接 import / 共享 ORM / 共享数据库连接

**Day 22-23 验证**:段 7.1 `dictionary_client.py` 完全用 httpx 调辞典 REST,未走任何 import / db connection 共享。

**为何**:物理隔离是商业模型分层的代码层映射。任何"嫌麻烦,辞典直接读 MLS 的 listing 集合"的捷径,违反此条。

### 铁律 2 · 数字资产定位

辞典是**独占数字资产**,MLS 是**可被接入的应用产品**。

- 辞典面向多个调用方(MLS 实例 / 第三方系统 / 未来 web 应用)
- MLS 面向一家公司在一个城市的经纪人

**Day 22-23 验证**:无破例。

**为何**:这条决定了所有边界——API 设计 / 权限模型 / 运营归属 / 商业模式。

### 铁律 3 · 运营动作归属

- 辞典数据治理(户型标准化 / discrepancy 复核 / 基础数据导入 / 权威值修正 / 标准资产管理)归**辞典自有员工**
- MLS 端运营只管 MLS 业务(用户 / 房源 / 申诉),**不碰辞典数据**
- 辞典 admin UI 暂未开发,V2.1 走 mongo shell + CLI 替代

**为何**:工作流分清,不会因 MLS 客服顺手改辞典数据破坏权威值。

### 铁律 4 · 权限分级预留

辞典内三级:**owner / senior / operator**。

- owner:全部权限,V2.1 阶段实际只 1 人(磊本人)
- senior:复核 discrepancy / 修改权威值 / 管理标准资产
- operator:基础数据录入(小区 / 区县 / 城市)+ 受 city_scope 限制

`city_scope` 字段挂在每个 owner / senior / operator 身上,operator 工作范围由 city_scope 限定。所有写操作必经 audit_log。

**V2.1 实施**:schema + 中间件全部就位,实际用户只 1 个 owner,无登录 UI(改库手发)。

**为何**:未来扩团队 0 代码改,加一个 user record 即可。

### 铁律 5 · 多租户预留

每个**外部调用方**(MLS 实例 / 第三方系统)独立 **API Key**。Key 携带:

- `city_scope`:允许操作的城市列表
- `permissions`:可调用的 endpoint 集合
- `active`:启用 / 停用开关

**V2.1 实施**:1 个 Key 给 MLS 用,Key 表 schema 完整,无管理 UI(改库手发)。

**为何**:未来扩张到第二个 MLS 实例(比如保定某公司接入)是改一行 JSON 的事,不是写代码。

### 铁律 6 · 数据归属边界

**辞典只持有"物理永久 + 客观可测"的字段**。具体边界见 §五。

辞典 12 字段 + 元数据 + 历史层。其余全部归 MLS。**任何字段归属调整动议,必须经 §五 显式更新,不允许"先在代码里改了再说"**。

**Day 22-23 验证**:段 7.2 schema 改造(MLS 删 6 物理字段)严格按 §五 边界执行。坑 49 是因为前端 filter 逻辑没跟动 schema 改造,**不是边界违反**。

**为何**:
- 物理永久 + 客观可测 → 多 LA 挂同一房,辞典裁决到唯一答案
- 主观描述 → 各 LA 自由发挥,放 claim 比对会污染 discrepancy(永远改不完)
- 营销字段 → 完全 listing 周期专属,跨 listing 不共享
- 协作流 / 客户 / agents → MLS 业务流程,跟辞典不打架

---

## 五、完整数据归属表(段 7.2-7.5 落地后定型版)

> **本章 V8.6 §五 重写**。V8.6 当时段 7 未起手,部分字段标"段 7 拍",
> 现在(Day 23)段 7.2-7.5 全部落地,V8.7 落最终值。

### 5.1 辞典持有字段

```
身份层(永久,唯一索引):
  city_id          ObjectId    引用 cities 集合
  district_id      ObjectId    引用 districts 集合
  community_id     ObjectId    引用 communities 集合
  building         string      楼号(纯数字字符串)
  unit             string      单元(纯数字字符串)
  room_no          string      房号(纯数字字符串)

物理可测层(claim 工作流):
  area_sqm         float       建筑面积(㎡)
  floor            int         所在楼层
  total_floor      int         总楼层
  rooms            int         室
  halls            int         厅
  bathrooms        int         卫

元数据:
  property_code         string     HMAC + base32,12 位(secret_key 算)
  authoritative_attrs   {field: value}     运营复核确定的权威值,部分字段有部分没有
  attribute_claims      [{...}]            历史所有 claim 列表
                                           (LA / listing / timestamp / values / unverified 标记)
  standard_assets       {floor_plan_url, real_photos[]}
  created_at / updated_at

历史层(永久不变,只追加):
  transaction_history   [{...}]    每笔成交事实
                                   (price_yuan, deal_date, ba_id, la_id, transaction_id)
  listing_history       [{...}]    每次挂牌摘要
                                   (listed_at, sold_at, listing_id, status, listing_price_wan)

治理层(辞典自身集合):
  property_discrepancies   差异工单(4 态:pending / confirmed_new / confirmed_history / needs_evidence)
  audit_logs               所有写操作留痕
  api_keys                 多租户预留
  cities / districts / communities  字典表
```

### 5.2 MLS 持有字段(段 7.2 改造后定型)

```
认证层:
  agents                JWT 认证基础(详见模块一 V8 spec)

客户运营层:
  customers             经纪人私有客户档案(详见模块二 V11 客户 Tab spec)

挂牌运营层(listing 文档,段 7.2 改造):

  ───── 辞典引用(段 7.2 新加) ─────
  property_id          ObjectId   引用辞典 property._id(冗余存,免每次反查)
  property_code        string     12 位 HMAC base32(冗余存,免每次反查)

  ───── 营销字段(MLS 持有) ─────
  price_wan            float
  bonus_yuan           int
  status               enum       (on_sale / deposit_paid / transaction_ongoing / sold / offline)
  status_label         string     (运行时拼,中文 status 显示用)
  owner_agent_id       ObjectId
  sale_points          string
  description / remarks string
  photos               [base64]   (V2.1 阶段 base64,P1 tech debt:迁对象存储)
  cover_thumbnail      string     (列表用缩略图 base64,与 photos[0] 同源压缩版)
  photo_count          int
  commission_doc_url   string
  listed_at / sold_at  datetime
  deposit_associated_showing_id   string

  ───── 主观描述字段(MLS 持有) ─────
  layout               string     "南北通透" / "南向为主" / 自由文本
  orientation          string     朝向(各 LA 自由)

  ───── 段 7.2 已物理删除字段 ─────
  ❌ area_sqm      → 改从辞典 fetch
  ❌ floor         → 改从辞典 fetch
  ❌ total_floor   → 改从辞典 fetch
  ❌ rooms         → 改从辞典 fetch
  ❌ halls         → 改从辞典 fetch
  ❌ bathrooms     → 改从辞典 fetch

  ───── 身份字段冗余保留(段 7.2 决议)─────
  city / district / community / community_id /
  building / unit / room_no / house_code
  
  保留理由:BA 列表卡片副标题 + LA 工作台需快速展示,
            免每条 listing 都调辞典 fetch。
  约束:任何写入这些字段必须先调辞典 identify_property
        反查标准化值,不允许直接写 user input。

协作流程层(完全归 MLS):
  showing_requests / showings / transactions / settlements

视图聚合层(MLS 自己拼装):
  dashboard 工作台聚合(数据来自上面集合)
```

### 5.3 字段查询性能优化(段 7.4 决议)

BA 视图(共享库列表 / listing 详情)需要返物理 6 字段,而 MLS 已删除这些字段,只能调辞典补。

**单条**:`GET /api/v1/listings/{id}` 内部 loop 调 `dict.get_property(property_code)` 拿 1 条 property。

**列表**(BA 共享库,可能 100+ 条 listing):为避免 N+1 问题,辞典段 7.4 新增批量 endpoint:

```
POST /v1/properties/batch
Body: { "codes": ["abc...", "def...", ...] }
Resp: { "abc...": {...}, "def...": {...}, ... }
```

MLS 端 `GET /api/v1/listings/shared` 内部:

1. 先拉本地 listings(身份字段冗余可用)
2. 收集所有 property_code
3. 一次调 `POST /v1/properties/batch`
4. 拼装返(listing 营销 + 辞典物理)

**关键**:BA 视图永远从辞典读最新物理(authoritative > claim 最近),**不用 listing 冗余**。冗余字段(身份 6)只用在不需要 fetch 的轻量场景(BA 卡片标题 "桥东区华新园 3 号楼 1 单元 502")。

### 5.4 联动接口(MLS → 辞典)

> Base URL: `http://<dict_ip>:8001/v1/`,所有调用必带 `X-API-Key` Header。

| 场景 | MLS 端动作 | 调用 endpoint | 辞典动作 |
|---|---|---|---|
| LA 挂牌(身份) | 用户填 city/district/community/building/unit/room_no | `POST /properties/identify` | 命中或创建 property,返 property_code |
| LA 挂牌(claim) | 用户填 6 物理字段 | `POST /properties/{code}/claims` | 比对裁决,200 接受 / 409 + diff(MLS 弹窗 LA) |
| LA 挂牌(force) | LA 弹窗确认无误后重发 | `POST /properties/{code}/claims?force=true` | 接受 + 写 discrepancy |
| BA 看共享库 | MLS 拉本地 listings | `POST /properties/batch` | 批量返物理(authoritative > 最近 claim)+ 标准资产 |
| BA 看详情 | MLS 拉单 listing | `GET /properties/{code}` + `GET /properties/{code}/transaction-history` | 返物理 + 历史成交 |
| LA 看自己 listing | MLS 编辑页加载 | `GET /properties/{code}` 比对 | 返 authoritative;MLS 端比 listing,渲染黄条 |
| LA 一键同步 | 黄条按钮 | `POST /properties/{code}/claims` (新值) | 提交新 claim,如一致直接接受 |
| 成交 confirmed | MLS 完成 transaction 写库后 | `POST /transactions` (sink) | 记 property.transaction_history[] |

### 5.5 字段命名漂移修正(V8.7 新增)

V8.6 一些字段名与代码现实有偏,V8.7 锁定:

| V8.6 文档名 | 代码实际名 | 备注 |
|---|---|---|
| `houses` 集合 | `listings` 集合 | 模块二 V11 spec 用 houses,代码用 listings,以 listings 为准 |
| `house_code` | `property_code` | 当前 listings 文档同时存 `house_code`(MLS 内部 12 位) + `property_code`(辞典 12 位) |
| `/api/houses/my` | `/api/v1/listings/mine` | 实际路由,V8.6 接口表漏了 `/api/v1/` 前缀 |
| `pending_dict_sinks` | `pending_dict_sinks` | 段 7.6 retry 队列,命名稳定 |

模块二 V11 spec 没改(spec 是产品文档,改名成本高),代码现实以 V8.7 为准。

---

## 六、辞典 4 层机制

> 本章 V8.6 §六 主体保留,经 Day 22-23 真机验证后**微调细节**。

辞典系统的核心是 4 层机制,从下到上:**身份 → 识别 → 裁决 → 事实**。

### 第 1 层 · 身份(HMAC 算码 + 6 字段唯一索引)

每套房在物理世界有唯一身份(6 字段)。算码模块 `services/coding.py` 用 HMAC-SHA256 把 6 字段 + secret_key 哈希成 12 位 base32 字符串,即 `property_code`。

特性:
- 同 6 字段输入 → 同 code 输出(确定性,幂等)
- 不同 6 字段输入 → 不同 code(碰撞概率极低)
- 反推不出 6 字段(单向哈希,防物理细节泄露)
- 不可读(base32 字符,跟"湛江/镇江/舟山" ZJK 双拼无关)

**关键约束**:secret_key 一旦改变,所有历史 code 失效。**生产 secret_key 与开发 secret_key 严格隔离**(`.env` 分文件,不入仓)。

### 第 2 层 · 识别(命中或创建,幂等)

`POST /v1/properties/identify` 收到 6 字段 → 算 code → 查 properties 表:

- 命中(同 code 已存在)→ 返既有 property
- 未命中 → 建新 property 文档,返新 property

**幂等**:同 6 字段反复调,永远返同一条 property。这是 MLS 端"先调辞典再写本地"双写模式的基石——**不怕重试,不怕并发**。

**Day 22 段 7.3 实测**:LA 挂牌反复测,即使两次 listing 不同,只要身份 6 字段相同,辞典永远返同一 property_code。

### 第 3 层 · 裁决(claim + 比对 + 复核 + 权威值)

LA 挂牌时对 6 物理字段提交 claim:

```
POST /v1/properties/{code}/claims
{
  "area_sqm": 100.5,
  "floor": 5,
  "total_floor": 18,
  "rooms": 3,
  "halls": 1,
  "bathrooms": 1,
  "source": {"agent_id": "...", "listing_id": "...", "force": false}
}
```

辞典内部裁决步骤:

**1. 比对优先级**(白名单驱动):
- `authoritative_attrs` 优先 → 缺则 `attribute_claims[]` 历史最近 → 都缺则不比对(首次直接接受)

**2. 三分支结果**:
- 全字段一致 → 接受 claim,沉淀到 attribute_claims[](标 verified=true)
- 不一致 + force=false → **返 409 + diff** `[{field, claimed_value, expected_value, expected_source}]`,MLS 端弹窗给 LA
- 不一致 + force=true → 接受 claim(标 unverified)+ **每差异字段写 1 条 discrepancy 工单**

**3. discrepancy 4 态**:
- `pending`(新生成,待运营复核)
- `confirmed_new`(运营复核确认 LA 是对的,**authoritative 更新为新值**)
- `confirmed_history`(运营复核确认历史值是对的,authoritative 设为历史值)
- `needs_evidence`(运营要求 LA 上传房本凭证再判)

**4. 复核必走**:不允许 dismiss,只能进 4 态之一。**杜绝"看着不顺手就关了"的 silent corruption**。

### 第 4 层 · 事实(transaction_history,只记不裁)

MLS 端成交 confirmed 时,调 `POST /v1/transactions` 把成交事实(price_yuan / deal_date / ba_id / la_id / transaction_id)推给辞典。辞典记到 `property.transaction_history[]`。

**特性**:
- 写入即终态,不可改
- 只记录,不裁决(即使两笔成交价差距大,辞典也都记着)
- 永久保留,跨 listing 不丢

**为何这是事实层**:成交是物理世界的真事(房子真的换了主),不是经纪人的主张。事实层只忠实记录,不参与博弈。

**段 7.6 实测**:LA confirmed 后强制同步调用辞典 sink,99.9% 走通。0.1% 辞典 5xx 时降级进 `pending_dict_sinks` 队列,APScheduler 每 5min retry。

### 4 层之间的关系

```
身份(永久)
    ↓
识别(读)── 命中或创建,返 property_code
    ↓
裁决(写,可比对)── claim 进 attribute_claims[],复核进 authoritative_attrs
    ↓
事实(写,不可改)── transaction 进 transaction_history[]
```

身份是基石(无身份则无 property)。识别是入口(所有交互先识别)。裁决是治理(争议在这层解决)。事实是终点(不参与博弈,只忠实记录)。

---

## 七、API 接口表(对照 Swagger 实测全量)

> **Day 23 实测来源**:`http://localhost:8000/docs` Swagger 页面。
> 全部路由前缀 `/api/v1/`(Day 23 验证此前缀,V8.6 接口表漏)。
> 此表是 MLS 端 endpoint 全量,辞典端 endpoint 见 §六。

### 7.1 认证(auth)

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/auth/send-sms-code` | 发短信验证码(开发态固定 123456) |
| POST | `/api/v1/auth/register` | 注册 |
| POST | `/api/v1/auth/login` | 登录 |
| POST | `/api/v1/auth/refresh` | 刷新 access token |
| POST | `/api/v1/auth/logout` | 登出 |
| GET | `/api/v1/me` | 当前用户信息 |

### 7.2 房源(listings)

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/listings` | LA 挂牌(段 7.3 双写) |
| GET | `/api/v1/listings/mine` | 我的房源列表(LA 视角) |
| GET | `/api/v1/listings/shared` | 共享库列表(BA 视角,段 7.4 批量 fetch) |
| GET | `/api/v1/listings/meta/districts` | 17 区县字典(给前端筛选用) |
| GET | `/api/v1/listings/{listing_id}` | listing 详情(含辞典物理 fetch) |
| PATCH | `/api/v1/listings/{listing_id}` | LA 编辑 |
| DELETE | `/api/v1/listings/{listing_id}` | LA 下架(status → offline) |
| POST | `/api/v1/listings/{listing_id}/mark-deposit-paid` | 标记定金已付 |
| POST | `/api/v1/listings/{listing_id}/mark-transaction-ongoing` | 标记成交进行中 |
| POST | `/api/v1/listings/{listing_id}/rollback-to-on-sale` | 回滚到在售 |
| POST | `/api/v1/listings/{listing_id}/reactivate` | 已下架 → 在售 |
| POST | `/api/v1/listings/{listing_id}/sync-physical` | **段 7.5.2.a 新增** · 一键同步辞典权威值 |

### 7.3 带客申请(showing-requests)

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/showing-requests` | BA 发起申请 |
| GET | `/api/v1/showing-requests/received` | LA 收到的申请 |
| GET | `/api/v1/showing-requests/sent` | BA 发出的申请 |
| GET | `/api/v1/showing-requests/pending-count` | 待审批数(LA 工作台角标) |
| GET | `/api/v1/showing-requests/{request_id}` | 申请详情 |
| POST | `/api/v1/showing-requests/{request_id}/approve` | LA 批准 |
| POST | `/api/v1/showing-requests/{request_id}/reject` | LA 拒绝(带理由) |

### 7.4 带看(showings)

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/showings` | BA 提交带看记录 |
| GET | `/api/v1/showings/pending-confirm` | LA 待确认带看列表 |
| GET | `/api/v1/showings/pending-confirm-count` | 待确认数(LA 工作台角标) |
| GET | `/api/v1/showings/by-request/{request_id}` | 通过申请 ID 查带看 |
| POST | `/api/v1/showings/{showing_id}/confirm` | LA 确认带看 |
| POST | `/api/v1/showings/{showing_id}/reject` | LA 驳回带看 |
| GET | `/api/v1/showings/can-direct` | 能否直接带看(B 版本) |
| POST | `/api/v1/showings/direct` | 直接带看(熟人模式) |
| GET | `/api/v1/showings/{showing_id}` | 带看详情 |

### 7.5 成交(transactions)

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/transactions` | BA 发起成交 |
| GET | `/api/v1/transactions/pending-la` | LA 待确认成交列表 |
| GET | `/api/v1/transactions/pending-la-count` | 待确认数(LA 工作台角标) |
| GET | `/api/v1/transactions/by-showing/{showing_id}` | 通过带看 ID 查成交 |
| POST | `/api/v1/transactions/{transaction_id}/la-confirm` | LA 独立填价确认(段 7.6 触发 sink) |
| POST | `/api/v1/transactions/{transaction_id}/la-reject` | LA 拒绝 |
| PATCH | `/api/v1/transactions/{transaction_id}/my-submission` | 我修改自己的提交 |
| POST | `/api/v1/transactions/{transaction_id}/cancel` | 取消成交 |
| GET | `/api/v1/transactions/{transaction_id}` | 成交详情 |

### 7.6 工作台(dashboard)

| Method | Path | 说明 |
|---|---|---|
| GET | `/api/v1/dashboard/summary` | 工作台数据摘要 |
| GET | `/api/v1/dashboard/todos` | 待办列表(Day 12 新增) |
| GET | `/api/v1/dashboard/recent-events` | 24h 事件流(Day 12 新增) |

### 7.7 小区(communities)

| Method | Path | 说明 |
|---|---|---|
| GET | `/api/v1/communities/search` | 搜索小区 |
| POST | `/api/v1/communities` | 提交新小区(走审核) |
| GET | `/api/v1/communities/{community_id}` | 小区详情 |

### 7.8 结算(settlements)

| Method | Path | 说明 |
|---|---|---|
| GET | `/api/v1/settlements/pending-my` | 我的待结算 |
| GET | `/api/v1/settlements/pending-my-count` | 待结算数(工作台角标) |
| POST | `/api/v1/settlements/{settlement_id}/la-mark-paid` | LA 标记已付奖金 |
| GET | `/api/v1/settlements/{settlement_id}` | 结算详情 |

### 7.9 客户(customers,Day 11 新增)

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/customers` | 创建客户 |
| GET | `/api/v1/customers/mine` | 我的客户列表 |
| GET | `/api/v1/customers/{customer_id}` | 客户详情 |
| PATCH | `/api/v1/customers/{customer_id}` | 更新客户 |
| POST | `/api/v1/customers/{customer_id}/memo` | 加跟进记录 |
| PATCH | `/api/v1/customers/{customer_id}/close` | 关闭客户(成交 / 不再跟) |
| GET | `/api/v1/customers/{customer_id}/timeline` | 客户时间线 |

### 7.10 协作(collaborations,Day 13 新增)

| Method | Path | 说明 |
|---|---|---|
| GET | `/api/v1/collaborations/mine` | 我的协作列表(协作 Tab 全生命周期) |

### 7.11 接口数总计

| 模块 | endpoint 数 |
|---|---|
| auth + me | 6 |
| listings | 12 |
| showing-requests | 7 |
| showings | 9 |
| transactions | 9 |
| dashboard | 3 |
| communities | 3 |
| settlements | 4 |
| customers | 7 |
| collaborations | 1 |
| **合计** | **61** |

(V8.6 §一 提到的"44 API endpoints"是 Day 21 末的快照,Day 22-23 段 7 接入 + 段 7.5 新增 sync-physical 后扩到 61 条)

---

## 八、模块完成度盘点 + 段 7 进度

### 8.1 模块完成度

| 模块 | spec 文档 | 完成度 | 备注 |
|---|---|---|---|
| 模块一(注册登录) | V8 App 版 | ✅ 100% | JWT + 短信验证码 + 生物识别预留 + 多设备管理 |
| 模块二(房源管理) | V11 App 版 | ✅ 段 7 接入完成 | 段 7.2 schema 改造 + 7.3 双写 + 7.5 黄条同步 UI |
| 模块三(共享房源库) | V7 App 版 | ✅ 段 7 接入完成 | 段 7.4 BA 视图 fetch + 批量 endpoint |
| 模块四(带客协作) | V9 App 版 | ✅ 100% | Day 13 协作 Tab 完成,17 条协作进度可视化(Day 23 真机确认) |
| 模块五(交易留痕) | V10 App 版 | ✅ 段 7.6 sink 完成 | 反作弊三分支 + transaction sink hook + 5xx 降级 retry |
| 模块六(Web 管理后台) | V7 | ⏸ V2.1 不做 | spec 锁定不变,V3 启动 |
| 模块七(推送消息) | V10 App 版 | ⏸ V2.1 简化 | 极光推送 schema 就位,实推服务后置 |

### 8.2 V2.1 #15 段 7 进度

| 段 | 任务 | Day | commit | 状态 |
|---|---|---|---|---|
| 7.1 | dictionary_client.py + 单测 | Day 22 | (推断) | ✅ |
| 7.2 | listing schema 改造(删 6 物理字段 / 加 property_id+code) | Day 22 | (推断) | ✅ |
| 7.3 | listing CRUD 双写(POST/PATCH/GET) | Day 22 | (推断) | ✅ |
| 7.4 | BA 视图 fetch + 批量 endpoint | Day 22 | (推断) | ✅ |
| 7.5.1 | 后端 GET /properties/{code} 比对 + 黄条数据 | Day 22 | (推断) | ✅ |
| 7.5.2.a | POST /listings/{id}/sync-physical endpoint | Day 22 | `74e420f` | ✅ |
| 7.5.2.b | listing_edit_screen 黄条 UI + 一键同步 | Day 22 | `d911f62` | ✅ |
| 7.5 真机回归 | 张三 LA 挂牌 → 黄条 → 同步 → 我的房源显示 | Day 23 | `179213b` | ✅(坑 49 修复后) |
| 7.6 | transaction sink hook + 5xx 降级 retry | Day 22 | (推断) | ✅ |
| 7.7 | 全套数据清空 + 真机回归(7 步) | Day 24 | 待 | ⏳ |

**段 7 收官里程碑**:Day 24 段 7.7 全清回归通过,即 V2.1 #15 收官,V2.1 整体收尾。

### 8.3 V2.1 路线图剩余

V8.6 §七 列出"V2.1 收缩为能用最小集"的边界,Day 22-23 推进后,V2.1 待办还剩:

| 项目 | 优先级 | 状态 |
|---|---|---|
| #15 段 7.7 全清回归 | P0 | Day 24 起手 |
| 社区库 MVP | P1 | 推迟到 V2.2(段 7 收官后再考虑) |
| Dashboard UI polish | P2 | 段 7.7 后做 |
| Logout 安全加固 | P2 | 段 7.7 后做 |
| 对象存储迁移(替换 base64 photo) | P1 tech debt | V2.2 启动(详见 §十一) |
| "我的"页面入口(头像在工作台右上) | P3 | 段 7.7 后做 |
| Web 管理后台(模块六) | V3 | 不在 V2.x 范围 |

---

## 九、Day 22-23 战绩(段 7 大爆发)

### 9.1 Day 22 战绩(11 commit · 段 7.1-7.6)

> commit hash 部分推断,具体见 `git log --oneline d911f62~12..d911f62`

Day 22 一天打掉段 7 全部子段(除 7.7 全清回归留 Day 24)。这是项目史上单日 commit 最密集的一天。

**段 7.1 dictionary_client.py 起手**

新建 `mls/backend/services/dictionary_client.py`,纯 httpx 客户端,接收 `DICT_BASE_URL` + `DICT_API_KEY` 环境变量。提供:

```python
class DictionaryClient:
    async def identify_property(...)     # → property_code
    async def get_property(code)         # → physical_attrs
    async def submit_claim(code, vals, force=False)  # 200 / 409
    async def sink_transaction(...)      # 99.9% 同步,5xx 降级
    async def batch_get_properties(codes)   # 段 7.4 批量
```

错误处理铁律:
- 网络错误 → `DictionaryUnavailableError`,LA 端弹"辞典服务不可达"
- 409 → `DictionaryConflictError(diff)`,LA 弹窗看历史值
- 403(API Key 无效 / city_scope 越界) → `DictionaryForbiddenError`,日志告警
- 5xx → 重试 1 次,仍失败抛 unavailable

dictionary_client 有完整单测(mock 辞典 HTTP),不依赖辞典服务真起。

**段 7.2 listing schema 改造**

- Pydantic 三处必改:doc / CreateRequest / UpdateRequest 全删 `area_sqm/floor/total_floor/rooms/halls/bathrooms`,全加 `property_id/property_code`
- migrate 脚本不写,V2.1 阶段全清(段 7.7),省事
- 隐含坑(待 review):Pydantic v2 `model_config` 默认 `extra='ignore'` —— 如果接口仍传旧字段,前端不知不觉构造了"看着像有"实际被静默丢的请求

**段 7.3 listing CRUD 双写**

```python
# POST /listings(LA 挂牌)
1. 验入参(身份 6 + 物理 6 + 营销若干)
2. dict.identify_property(身份 6) → property_code + property_id
3. dict.submit_claim(code, 物理 6, force=False)
   ├─ 200 → 进 4
   └─ 409 → 返前端 (diff + property_history),让 LA 弹窗 → force=true 重发
4. db.listings.insert_one(身份 6 冗余 + property_id + property_code + 营销)
5. 返新建 listing
```

PATCH 与 GET 同套思路,GET 把本地 listing(营销)+ 辞典 fetch(物理)拼装返。

**段 7.4 BA 视图 fetch + 批量 endpoint**

辞典侧补 `POST /v1/properties/batch`,接受 codes 数组返批量物理。MLS 端 `GET /listings/shared` 一次调拿全部,解决 N+1。

**段 7.5 LA 编辑页黄条**(2 commit)

- `74e420f` 段 7.5.2.a:`POST /listings/{id}/sync-physical` endpoint。LA 黄条按钮调这个,后端代为提交 claim。
- `d911f62` 段 7.5.2.b:listing_edit_screen 黄条 UI + 一键同步权威值 + 删 silent fail 字段。silent fail 字段是指段 7.2 删的 6 个物理字段,前端表单还残留 input,改完没人接收,Day 22 末顺手清。

**段 7.5.2.b 后真机回归未跑**——这是 Day 22 收工时留下的尾巴,Day 23 接手。

**段 7.6 transaction sink hook**

`mls/backend/transactions.py` 的 `la_confirm` 函数,confirmed 时调 `dict.sink_transaction`。强制同步路径(99% 走这条),5xx 降级到 `pending_dict_sinks` 队列。

APScheduler 每 5min 扫一次 retry 队列,retry_count <= 5,成功即删除。

### 9.2 Day 23 战绩(1 commit · 段 7.5 真机回归收尾)

`179213b` fix(listing): filter matches 漏 isActive 守卫导致列表全空 (V8.7 坑 49)

**事故时序**:
- Day 22 段 7.5 4 子段全 push,真机回归未跑
- Day 23 开工诊断 1.5h(curl 后端验 9 条返回正常 → mongosh 验 ObjectId 类型正常 → dio 超时排查 → 静态读 `_filters.matches` 1 分钟破案)
- 修复 10min:`_processItems` 调 matches 前加 `_filters.isActive` 守卫
- 修复半径:`listing_list_screen.dart` + `listing_shared_screen.dart` 两处(grep 确认)

详见 §十 坑 49。

### 9.3 Day 22-23 关键决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 段 7.2 migrate 脚本 | 不写,V2.1 全清省事 | 测试期数据无价值,正式前 archive 备份即可 |
| 批量 endpoint 位置 | 辞典侧加 `POST /properties/batch` | MLS 端不批量缓存,辞典做单一事实源 |
| 段 7.6 sink 策略 | 强制同步 + 5xx 降级 retry 队列 | 99.9% 强一致,0.1% 短期不一致但运营可见 |
| 段 7.7 数据清空 | C 选项 — 辞典清业务保字典 | 17 区县 + 已审核小区不重建 |
| filter isActive 守卫 | 显式契约,不做单字段 null 兜底 | 避免后续坑 50+,语义清晰 |

---

## 十、坑账总集 1-49(分类整理)

> 本章承接 V8.5 / V8.6 的 坑 1-37,新增 Day 21-22 推断 11 个登债(38-48)+ Day 23 实录坑 49。
> Day 21-22 11 个登债基于 commit log + memory + 段 7 流程推断,**待磊 review 修订**(标 ⚠ 推断)。

### 10.1 坑账分类索引

| 类别 | 坑号 | 主题 |
|---|---|---|
| **A. 环境配置** | 13-18 | Windows / Android SDK / Gradle / VPN / 镜像 |
| **B. Dart / Flutter 语言陷阱** | 25, 27, 32 | enum global-search / Spacer 键盘 / IntrinsicHeight |
| **C. Pydantic / FastAPI** | 28 | silent discard 字段 |
| **D. VS Code 工作流** | 26 | 大文件替换 |
| **E. 权限 / Manifest** | 29 | url_launcher 拨号 queries |
| **F. 跨语言类型系统** | 30 | ObjectId vs str 不匹配 |
| **G. UI 状态管理** | 11, 31 | FutureBuilder 时序 / setState 漏触发 |
| **H. 段 7 重构期推断** | 38-48 ⚠ | dictionary_client / schema 改造 / 双写 / 批量 |
| **I. Day 23 实录** | 49 | filter matches 缺 isActive 守卫 |

### 10.2 A 类 · 环境配置坑(承袭 V8.5)

**坑 13**:Windows path 含中文 / 空格断 Android SDK config。规则:**`C:\projects\` 下不要中文目录名**。

**坑 14**:Android Studio wizard 的 Finish 按钮永远 grayed out。绕路:Cancel → More Actions → 直接配 SDK 路径。

**坑 15**:Android Studio 默认不装 Command-line Tools。`flutter doctor` 报 Android toolchain 不全时,SDK Manager → SDK Tools → 勾 Android SDK Command-line Tools 装上。

**坑 16**:Gradle 编译时 Java 进程残留导致 lock。修复:
```cmd
taskkill /F /IM java.exe
del /S /Q %USERPROFILE%\.gradle\caches\modules-2\files-2.1\<相关包>
del /S /Q <项目>\android\.gradle
```

**坑 17**:VPN 必须用 TUN 模式 / 增强模式。系统代理只走浏览器,cmd / Gradle / pip 不走代理 → 镜像源失败。

**坑 18**:Gradle / Maven 镜像必须永久配置在 3 个文件:
- `gradle-wrapper.properties` → Gradle 本身下载源
- `build.gradle.kts` → 依赖 Maven 仓库
- `settings.gradle.kts` → settings.repositories 同样改

任改一个不够,3 个都改才能保证 Gradle full pipeline 用国内镜像。

### 10.3 B 类 · Dart / Flutter 语言陷阱

**坑 25**:Dart enum 加新值后,**全文 grep 所有 `switch` 语句**。Dart 不强制 exhaustive,默认 fall through 到 default,加了新值不补 case 就 silent bug。

**坑 27**:`Scaffold + Column + Spacer` 键盘弹起溢出。简单修复:外层用 `SingleChildScrollView` 包,Spacer 改 `SizedBox(height: ...)`。复杂修复:用 `LayoutBuilder` + `ConstrainedBox`。

**坑 32**:`Spacer` / `Expanded` 放在 `ListView` 卡片内会崩(ListView 主轴无界,Expanded 拿不到高度)。修复:外层包 `IntrinsicHeight`。

### 10.4 C 类 · Pydantic / FastAPI

**坑 28**:Pydantic Update 模型未声明的字段被静默 discard。具体场景:Update model 里漏写一个字段,接口仍接受请求体里有这字段,但保存到 DB 时这字段被丢弃,**前端不报错,后端不报错,数据没存上**。

修复规则:
- Update 模型必须显式声明所有可更新字段
- 用 `model_config = ConfigDict(extra='forbid')` 强制拒绝未声明字段
- 任何 schema 改造后**全文 diff 三处:doc / CreateRequest / UpdateRequest**

### 10.5 D 类 · VS Code 工作流

**坑 26**:VS Code 大文件(>500 行)粘贴有时序问题。整文件替换工作流:

```
Ctrl+A          (全选)
等 1 秒          (让 VS Code 反应过来)
Delete          (清空)
等 1 秒          (确认空)
Ctrl+V          (粘贴新内容)
Ctrl+End        (跳到末尾,确认完整)
Ctrl+S          (保存)
```

不要用 find-and-replace 改大段,不要分段贴,不要"改一小块就保存"循环。

### 10.6 E 类 · 权限 / Manifest

**坑 29**:url_launcher `tel:` 拨号在 Android 11+ 上需 Package Visibility。`AndroidManifest.xml` 加:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.DIAL" />
    <data android:scheme="tel" />
  </intent>
</queries>
```

改完**必须 q 退当前 flutter run + 重新 `flutter run`**,hot reload 不生效(Manifest 是 build-time)。

### 10.7 F 类 · 跨语言类型系统

**坑 30**:MongoDB ObjectId vs Python str / Dart String 不匹配。

具体场景:
- DB 里 `owner_agent_id` 存为 `ObjectId("...")`
- JWT decode 得到 `current_user.id` 是 `str`
- 直接 `db.find({"owner_agent_id": current_user.id})` 用 str 查 ObjectId → **匹配 0 条**

修复:
```python
from bson import ObjectId
db.find({"owner_agent_id": ObjectId(current_user.id)})
```

诊断方法:
```cmd
mongosh
use mls
db.listings.findOne({}, {owner_agent_id: 1})
# 看返回 ObjectId("...") vs "..." 字符串
```

Day 23 诊断坑 49 时怀疑过此坑,实测后端代码 `agent["_id"]` 已是 ObjectId,**未触发**。但留作通用诊断模板。

### 10.8 G 类 · UI 状态管理

**坑 11**:FutureBuilder 异步时序 → 数据闪一下消失或 setState 与 build 竞争。

**坑 31**:setState 在 dispose 后调用 → mounted 检查必加。

### 10.9 H 类 · 段 7 重构期推断坑(38-48 ⚠ 推断)

> **以下 11 条基于 commit log + memory + 段 7 流程合理推断**,具体细节磊 review 后确认或修订。
> 推断方法:看每段 7.X 的预期工作量 vs 段实际行数,合理估测会撞的工程问题。

**⚠ 坑 38**:dictionary_client.py httpx 超时配置遗漏。段 7.1 起手时,httpx 默认 timeout 5s,辞典首次冷启动可能超过。修复:`httpx.AsyncClient(timeout=10.0)`。

**⚠ 坑 39**:dictionary_client 单测 mock 边界。pytest mock 的 httpx response 必须匹配实际辞典响应 schema 才能跑通,初次写时漏 `success` 字段或 `data` 包装层导致单测虚假通过。

**⚠ 坑 40**:段 7.2 listing schema 改造,Pydantic v2 `model_dump()` vs `dict()` 差异。v2 推荐 `model_dump()`,代码中残留 `.dict()` 调用产生 deprecation warning,严格模式下会失败。

**⚠ 坑 41**:段 7.2 后,前端 listing model fromJson 还在 `required: true` 找 area_sqm 等已删字段。这是段 7.5 真机回归的远因,但段 7.5.2.b 已"删 silent fail 字段"应该修了部分。剩余的会触发坑 50(详见 §十一)。

**⚠ 坑 42**:段 7.3 双写顺序:**必须先调辞典 identify,再 submit_claim,再写本地**。调换顺序会导致 listing 写入但辞典无 property,造成 dangling reference。

**⚠ 坑 43**:段 7.3 LA 挂牌 force=true 流程,前端弹窗确认后**必须用同一份 6 物理字段重发**,不能让用户中途修改。否则辞典会基于新值再次比对,可能再次 409,陷死循环。

**⚠ 坑 44**:段 7.4 批量 endpoint 的 codes 数组上限。辞典侧应限制单次最多 100 codes,超出需分页。BA 共享库长列表场景需考虑。

**⚠ 坑 45**:段 7.4 BA 视图详情页拼装,辞典 fetch 失败时降级策略:**降级到 listing 冗余的"待补"状态**,而不是整页报错。

**⚠ 坑 46**:段 7.5 黄条比对时,authoritative_attrs 部分字段为 null 是合法状态。比对逻辑必须 skip null,否则会误报"不一致"。

**⚠ 坑 47**:段 7.6 sink 强制同步路径下,**MLS 事务 commit 与辞典 sink 不在同一事务**。设计上接受这种最终一致(0.1% retry 兜底),但代码注释必须显式说明,不要以为有跨服务事务。

**⚠ 坑 48**:段 7.6 retry 队列幂等性。pending_dict_sinks 文档应有 `transaction_id` 唯一索引,APScheduler 重复跑不会写双份 transaction_history。

> Day 24 段 7.7 真机回归过程中,以上 11 条会逐条验证 / 修订。届时把"⚠ 推断"标记去掉,补具体 commit / 行号。

### 10.10 I 类 · Day 23 实录坑 49(详写)

**坑 49 · filter matches 漏 isActive 守卫,导致我的房源 9 条全空**

**触发场景**:
段 7.2 后端删除 listing 物理 6 字段(area_sqm/floor/total_floor/rooms/halls/bathrooms),迁辞典。前端 Flutter 端 `listing_filters.dart` 的 `matches()` 函数仍用:

```dart
final area = (item['area_sqm'] as num?)?.toDouble() ?? 0;
if (area < minArea || area > maxArea) return false;
```

`area_sqm` 段 7.2 后永远为 null → `?? 0` 兜底 → area=0 < minArea(默认 30)→ **matches 永远返 false**。

`_processItems` 调 matches 前**无 isActive 守卫**:

```dart
items.where((item) {
  ...
  if (!_filters.matches(item)) return false;  // ← 永远 false
  return true;
})
```

结果:即使筛选条件是空(`ListingFilters.empty`),9 条 listing 全被过滤,UI 显示空列表。

**触发文件**:`mls/app/mls_app/lib/screens/listing_list_screen.dart` + `listing_shared_screen.dart`(共享库同模式)

**事故时序**:
- Day 22 段 7.5.2.b commit `d911f62` "删 silent fail 字段" 删的是表单字段,但 filter 模型未跟改
- Day 22 末段 7.5 4 子段全 push,真机回归未跑
- Day 23 开工:张三登录后"我的房源"显示空,DB 实有 9 条,GET /listings/mine 返 9 条
- 1.5h 诊断:curl 验后端 → mongosh 验 ObjectId 类型 → dio 超时排查 → 静态读 _filters.matches 1 分钟破案

**修复方案**:_processItems 调 matches 前加 isActive 守卫,**空筛选 = 不过滤**显式契约:

```dart
if (_filters.isActive && !_filters.matches(item)) return false;
```

**修复半径**:listing_list_screen.dart + listing_shared_screen.dart 两处(grep 确认)。`isActive` getter `listing_filters.dart:43` 已存在(`bool get isActive => !isEmpty;`)。

**架构教训**:
- 任何 schema 改动后,**前端凡是读这些字段的地方必须全文搜一遍**,grep 字段名,不是只盯 model 类
- 筛选器 / 过滤器函数应有"isActive 守卫"做显式契约——空筛选 = 不过滤。让"默认值是否激活筛选"不再依赖单字段兜底语义。
- 这是适用于 customers / showings / transactions 所有列表筛选的通用规则,Day 24 全清回归时全模块自检一遍

**关联现象**(本次诊断顺手暴露,候选坑见 §十一):
- 卡片副标题 `null㎡ · null/null层` 渲染未做 null 处理 → 候选坑 50
- 8 张 listing 共用同一占位封面图 → 候选坑 51(测试数据残留,段 7.7 全清后消解)
- `/listings/mine` 387KB 响应体(9 条带 base64 封面)→ 候选坑 52(P1 tech debt)

**commit hash**:`179213b`

---

## 十一、技术债 candidates(坑 50-52 + 已知 tech debt 列表)

> 这一章是**已暴露未修**的清单。修复优先级与时机各不同。

### 11.1 候选坑 50 · 卡片副标题 null 字段渲染

**症状**:Day 23 真机截图显示 `null㎡ · null/null层`。

**根因**:段 7.2 后端删了 6 物理字段,前端卡片副标题渲染逻辑还在拼这些 null。`'${item["area_sqm"]}㎡ · ${item["floor"]}/${item["total_floor"]}层'` 格式串里 null 直接转字面量字符串。

**短期修复**(可顺手):前端检测 null → 显示"待补"或干脆隐藏整行。

**中长期修复**(段 7.4 战略路径):BA 视图按 V8.6 §八.3 段 7.4 从辞典 fetch 物理属性补字段。LA 自己挂的房,自己之前填过的物理值也在辞典里了,可一并 fetch 显示。

**优先级**:Day 24 段 7.7 全清前修(短期方案),全清后用真实辞典数据自然消解(长期方案)。

### 11.2 候选坑 51 · 测试 listing 共用同一占位封面

**症状**:Day 23 截图 9 套房中 8 套用同一张"绿色像素块小屋"占位图。

**根因**:Day 8 photo MVP 测试时批量灌的同一张测试图,base64 数据同源。

**修复**:不修。段 7.7 全清后这 9 条数据 archive 备份,正式期由 LA 自己挂房上传真实照片。

**优先级**:无,自然消解。

### 11.3 候选坑 52 · 列表 API 返 base64 封面(P1 tech debt)

**症状**:`GET /api/v1/listings/mine` 9 条响应体 387KB,base64 封面图占大头。100 条时 4MB,**必崩**。

**修复方案**:对象存储迁移 + 列表 API 改返 thumbnail_url 字符串:

```
当前:listing.cover_thumbnail = "data:image/jpg;base64,/9j/4AAQ..."  (~30-50KB/条)
改为:listing.cover_thumbnail_url = "https://cos.../thumb/abc.jpg"   (~80 字节/条)
```

**优先级**:P1 tech debt,V2.2 启动。在此之前控制单页 listing 数 ≤ 20 条避免崩盘。

### 11.4 已知 tech debt(承袭并更新)

| 项目 | 优先级 | 说明 | 触发条件 |
|---|---|---|---|
| 对象存储迁移(替换 base64) | **P1** | 当前 photos 字段直接存 base64,坑 52 是其表面症状 | 房源量 > 50 时启动 |
| Logout 安全加固 | P2 | 当前 logout 仅清本地 token,server 侧 token 黑名单未实现 | 上线前 |
| Dashboard UI polish | P3 | 工作台视觉打磨 | 段 7.7 后做 |
| "我的"页面入口 | P3 | 头像在工作台右上角 | 段 7.7 后做 |
| 真机 IP 自动发现 | P3 | App baseUrl 当前硬编码,IP 变了要改 | 用户增多后 |
| Web 管理后台(模块六) | V3 | 全量 spec 在 V7,V2.x 不做 | V3 启动 |
| 推送服务接入(模块七) | V2.x 后期 | 极光 schema 就位,实推未接 | V2.2 启动 |

---

## 十二、Day 24 起手锚点

### 12.1 Day 24 主线任务

**V2.1 #15 段 7.7 全套数据清空 + 真机回归**(0.5-1d)

完成此段即 V2.1 #15 收官,V2.1 整体收尾。

### 12.2 Day 24 子任务序列

**T1 · archive 备份**(5min)

```cmd
REM 在 monorepo 根创建 archive 目录(进 .gitignore)
mkdir C:\projects\archive

REM 把根目录 .gitignore 加 "archive/" 一行(若未配置)
echo archive/ >> C:\projects\.gitignore

REM dump MLS 整库(含 agents / customers / listings / showings / 
REM showing_requests / transactions / settlements 等所有业务集合)
mongodump --db mls --out C:\projects\archive\mls_pre_v2_1_20260509

REM 期望:archive\mls_pre_v2_1_20260509\mls\*.bson 一系列文件
```

**T2 · 写 reset_to_v2_1.py**(30min,MLS 侧)

辞典侧 `reset_to_v2_1.py` Day 21 已有(`5b31d82`),MLS 侧本子段写。

期望行为:
- 清:agents / customers / listings / showings / showing_requests / transactions / settlements
- 保留:communities(MLS 缓存的小区,如有)
- 幂等执行,反复跑不出错

**T3 · 双侧执行清空**(2min)

```cmd
REM 辞典侧
cd C:\projects\property-dictionary\backend
venv\Scripts\activate
python scripts\reset_to_v2_1.py
REM 期望:清业务,留 17 districts + 已审核 communities + 测试 API Key

REM MLS 侧
cd C:\projects\mls\backend
venv\Scripts\activate
python scripts\reset_to_v2_1.py
```

**T4 · 真机回归 7 步**(2-4h)

| 步 | 操作 | 期望 |
|---|---|---|
| 1 | 张三注册 → 挂第一套(中泰城) | 辞典识别小区 → property → 接受 claim → MLS 写 listing |
| 2 | 李红注册 → 看共享库 | 看到中泰城,物理属性来自辞典 |
| 3 | 李红申请带看 → 张三批 → 双方确认 | 协作链全跑通 |
| 4 | 李红发起成交 → 张三独立填 | confirmed → 辞典 sink_transaction → property.transaction_history 多 1 条 |
| 5 | 张三第二套(同 building 同 unit 不同 room_no) | 辞典创建新 property |
| 6 | 张三第三套(同 building 同 unit 同 room_no,即已成交那套) | 辞典命中既有 property → claim 比对 → 一致直接接受 / 不一致走黄条 |
| 7 | 张三恶意填错面积 | 辞典 409 → LA 弹窗看历史值 → force=true → discrepancy 工单生成 |

**T5 · 推断坑 38-48 验证**(嵌入 T4)

T4 执行过程中,§十.9 推断的 11 个登债逐条验证。验证后:
- 实际撞了 → 修 + 标 ✅ + 补具体 commit / 行号
- 没撞 → 标 ✓ 不需修(或降级到候选)
- 撞了不同坑 → 新增坑号

**T6 · 坑 50 短期修复**(20min,可在 T4 前做也可后做)

`listing_list_screen.dart` + `listing_shared_screen.dart` 卡片副标题 null 检测:

```dart
// 当前
'${item["area_sqm"]}㎡ · ${item["floor"]}/${item["total_floor"]}层'
// 改为
[
  if (item['area_sqm'] != null) '${item["area_sqm"]}㎡',
  if (item['floor'] != null && item['total_floor'] != null) 
    '${item["floor"]}/${item["total_floor"]}层',
].join(' · ')
```

或更彻底:从辞典 fetch 真实值。但段 7.7 全清后挂第一套就能拿到真实辞典数据,届时这个修复半自然消解,看磊偏好。

**T7 · 收官 commit + push**(5min)

```
git add -A
git commit -m "feat(V2.1 #15 段 7.7): 全清回归通过 + V2.1 收官"
git push origin main
```

### 12.3 Day 24 不做的

- ❌ 社区库 MVP(推迟到 V2.2)
- ❌ 对象存储迁移(P1 tech debt 但工作量大,V2.2)
- ❌ 模块六 Web 管理后台(V3)
- ❌ 模块七推送服务实接(V2.x 后期)
- ❌ V8.8 长期档(等 Day 25 再写)

### 12.4 Day 24 开工密码模板

```
任务:Day 24 V2.1 #15 段 7.7 · 全套数据清空 + 真机回归(V2.1 收官)

工程路径:C:\projects\mls\

承接:Day 23 末 V8.7 长期档(段 7.5 真机回归通过节点 179213b)

按 V8.7 §十二 12.2 子任务序列执行:
1. T1 archive 备份(5min)
2. T2 写 mls 侧 reset_to_v2_1.py(30min)
3. T3 双侧执行清空(2min)
4. T4 真机回归 7 步(2-4h)
5. T5 推断坑 38-48 嵌入 T4 验证
6. T6 坑 50 短期修复(20min,T4 前后皆可)
7. T7 收官 commit + push

铁律:
- cmd 不用 PowerShell
- VS Code 大文件 Ctrl+A → 等 1s → Delete → 等 1s → Ctrl+V
- AndroidManifest 改后 q + flutter run
- granular commit
```

---

## 十三、协作约定 + 工作流铁律(承袭并更新)

### 13.1 会话起手协议

新会话第一条消息标准格式("开工密码"):

```
任务:[Day N · V2.X #M · 段 X.Y 名称]

工程路径:C:\projects\mls\

承接:[上次结束节点 commit hash + 描述]

[本次具体任务步骤,或引用 V8.7 §十二 子任务序列]

铁律:
- cmd 不用 PowerShell
- ...
```

### 13.2 commit 协议

**Granular commit**:每个独立改动一个 commit。

**Message 格式**:

```
<type>(<scope>): <description> [(<追溯标签>)]

<空行>

<详细说明:何 / 为何 / 关联事故时序 / 修复半径>

<空行>

<里程碑标记(可选,如:段 X.Y 真机回归通过节点)>
```

类型(type):`feat` / `fix` / `refactor` / `chore` / `docs` / `test`
作用域(scope):`listing` / `showing` / `transaction` / `customer` / `auth` / `dashboard` / `dict-client`
追溯标签(可选):`V8.7 坑 49` / `V2.1 #15 段 7.5`

### 13.3 文件操作铁律

- **VS Code 大文件替换**:Ctrl+A → 等 1s → Delete → 等 1s → Ctrl+V → Ctrl+End → Ctrl+S
- **不用 find-and-replace 改大段**
- **不用分段贴**
- **AndroidManifest.xml 改后 q + flutter run**(不能 hot reload)

### 13.4 调试协议

debugPrint 使用 emoji 前缀分类:

| emoji | 含义 | 用途 |
|---|---|---|
| 📋 | FETCH | API 请求响应日志 |
| 🔧 | PROCESS | 数据处理中间步骤 |
| 🎨 | RENDER | UI 渲染日志 |
| 📸 | UPLOAD | 文件 / 图片上传 |
| 📱 | DEVICE | 设备相关 |
| 🔐 | AUTH | 认证 / token |
| ❌ | ERROR | 错误捕获 |
| ⚠️ | WARN | 警告 |
| ✅ | SUCCESS | 关键成功节点 |

调试日志**临时性**,定位完成后删除。如保留长期,改为 `logger.debug` 级别加配置开关。

### 13.5 长期档版本协议

| 版本号 | 触发条件 |
|---|---|
| V8.X(小版本) | 单日进度小,增量补丁 |
| V8.X+1(小版本) | 单日进度大,需要档案级更新 |
| V9.0(大版本) | V2.X → V3 阶段切换 |

**V8.6 → V8.7**:跨度 2 天(Day 22-23),11 commit + 1 commit + 1 个新坑详写,**完整重写**触发。

**V8.7 → V8.8**:Day 24 段 7.7 收 V2.1 后,根据收官内容决定增量补丁或完整重写。

### 13.6 推断式坑账协议

V8.7 §十.9 引入"推断式坑账"(标 ⚠ 推断)。规则:

- 推断坑必须标 ⚠
- 推断坑不算正式登债,Day N+1 验证后转正
- 验证未撞 → 标 ✓ 降级或注销
- 验证撞了不同问题 → 拆分新坑号

**为何引入**:Day 22 11 commit 一天打掉,具体撞过的坑磊本人也记不清细节,但合理推测有助于 Day 24 真机回归时**带着假设清单去验证**,比从 0 撞起来快。

---

## 十四、常用命令速查

### 14.1 启动

```cmd
REM MLS 后端
cd C:\projects\mls\backend
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000

REM 辞典后端
cd C:\projects\property-dictionary\backend
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8001

REM MLS App
cd C:\projects\mls\app\mls_app
flutter run

REM MongoDB(若未跑)
mongod --dbpath C:\data\db
```

### 14.2 验证

```cmd
REM Swagger
start http://localhost:8000/docs
start http://localhost:8001/docs

REM 当前 IP
ipconfig

REM 真机连通(替换 IP)
adb shell ping -c 3 192.168.1.X

REM Flutter 健康检查
flutter doctor -v
```

### 14.3 数据库

```cmd
REM 进 mongosh
mongosh

REM 在 mongosh 里
use mls
db.listings.countDocuments({})
db.listings.findOne({}, {_id: 1, owner_agent_id: 1})
db.agents.find({phone: "13912345678"})

REM 切辞典 db
use property_dict
db.properties.countDocuments({})
db.properties.findOne()

REM 退出
exit
```

### 14.4 Git

```cmd
REM 状态
git -C /c/projects/mls status --short
git -C /c/projects/mls log --oneline -10

REM 提交(在工程根目录跑)
cd C:\projects\mls
git add -A
git commit -m "<message>"
git push origin main

REM 看 Day 22 commit 范围
git log --oneline d911f62~12..d911f62

REM 查特定文件历史
git log --oneline -- app/mls_app/lib/screens/listing_list_screen.dart
```

### 14.5 短信验证码 + 登录(curl)

```cmd
REM 1. 发验证码
curl -X POST http://localhost:8000/api/v1/auth/send-sms-code ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13912345678\"}"

REM 2. 登录(开发态固定 123456)
curl -X POST http://localhost:8000/api/v1/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13912345678\",\"code\":\"123456\"}"

REM 3. 用 token 调接口(替换 token)
curl http://localhost:8000/api/v1/listings/mine ^
  -H "Authorization: Bearer <access_token>"
```

### 14.6 archive 备份(Day 24 用)

```cmd
mkdir C:\projects\archive
echo archive/ >> C:\projects\.gitignore
mongodump --db mls --out C:\projects\archive\mls_pre_v2_1_20260509
mongodump --db property_dict --out C:\projects\archive\dict_pre_v2_1_20260509
```

### 14.7 镜像源验证

```cmd
REM Gradle 拉取测试
cd C:\projects\mls\app\mls_app\android
gradlew --version

REM Maven 拉取测试(在 build.gradle 里看 repositories 配置)
type build.gradle.kts | findstr "aliyun"
```

### 14.8 reset 命令(开发期常用)

```cmd
REM Java 进程杀干净(坑 16)
taskkill /F /IM java.exe

REM Gradle 缓存清(只清,慎执行)
rmdir /S /Q %USERPROFILE%\.gradle\caches

REM Flutter 缓存清
flutter clean
flutter pub get

REM Android 项目 .gradle 清
cd C:\projects\mls\app\mls_app\android
rmdir /S /Q .gradle
```

---

## 十五、附录

### 15.1 测试账号速查

| 账号 | 手机号 | 角色 | agent_id | 备注 |
|---|---|---|---|---|
| 张三 | 13912345678 | LA | `69e45ec6e52ec020aa924065` | Day 23 实测 9 listing |
| 李红 | 13200132000 | BA | (Day 24 全清前不锚) | 协作 BA 端 |
| 验证码 | — | — | `123456` | 开发态固定,生产前移除 |

### 15.2 路径速查

```
项目根                 C:\projects\
MLS 后端              C:\projects\mls\backend\
MLS 前端              C:\projects\mls\app\mls_app\
辞典后端              C:\projects\property-dictionary\backend\
MongoDB 数据          C:\data\db\
archive 备份         C:\projects\archive\(.gitignore)
长期档             C:\projects\mls\docs\MLS交接文档V8.7.md(本档)
```

### 15.3 端口速查

| 服务 | 端口 |
|---|---|
| MLS 后端 | 8000 |
| 辞典后端 | 8001 |
| MongoDB | 27017(默认) |
| Flutter DevTools | 9100(默认) |

### 15.4 GitHub 远端

```
git@github.com:leelei-hub/mls.git
分支:main
最新 hash(Day 23 末):179213b
```

### 15.5 docs 目录建议结构

```
mls/docs/
├── MLS交接文档V8.7.md       (本档,长期档,当前 ground truth)
├── MLS交接文档V8.6.md       (历史档,作废保留)
├── MLS交接文档V8.5.md       (历史档)
├── ...
├── MLS_模块一V8_经纪人注册与登录_App版.md
├── MLS_模块二V11_房源管理_App版.md
├── MLS_模块三V7_共享房源库_App版.md
├── MLS_模块四V9_带客协作_App版.md
├── MLS_模块五V10_交易留痕与争议处理_App版.md
├── MLS_模块六V7_Web管理后台_保持不变.md
├── MLS_模块七V10_推送消息_App版.md
└── MLS_已确认决策汇总V10_App版.md
```

---

## V8.7 收档总结

**Day 22-23 共完成**:V2.1 #15 段 7.1-7.6 全部 + 段 7.5 真机回归通过 + 12 commit push 远端。

**坑账增量**:38-49 共 12 条(38-48 推断 11 条 + 49 实录 1 条)。候选坑 50-52 暴露未修。

**架构状态**:
- 双服务架构稳定(MLS + 辞典)
- 数据归属边界清晰(段 7.2 字段级删迁完成)
- 4 层机制经真机验证可工作
- 协作链全跑通(Day 23 协作 Tab 17 条进度可视化确认)

**Day 24 锚点**:V2.1 #15 段 7.7 全清 + 真机回归 7 步 → V2.1 收官。

**V8.7 写作时长**:Day 23 末 Web Claude ~2.5h。

**V8.8 触发条件**:Day 24 段 7.7 收官内容决定(增量 or 完整重写)。

---

> 本档由磊 + Claude(Anthropic Claude Opus 4.7)协作撰写。
> "机制服务于信任的演化" —— MLS 张家口实例,V2.1 即将收官。
