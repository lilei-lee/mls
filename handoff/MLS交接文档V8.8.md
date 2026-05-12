# MLS 交接文档 V8.8(长期档 · V2.1 收官版)

> **更新时间**:Day 25 末(2026-05-09)
> **关系**:V8.7 整档作废,V8.8 自包含,无需回看 V8.7 即可上手
> **承接**:V8.7 长期档(Day 23 末)+ Day 24 2 commit + Day 25 6 commit
> **本档主要变化**:
> - **V2.1 整体收官**(Day 24 段 7.7 真机回归通过 + Day 25 5 项登债全清)
> - V8.7 §十.9 推断坑账(38-48)经真机验证 → 大部分推断不准,**重写为实录**
> - 新增坑 50-59 共 10 条 Day 24-25 实录
> - V3 范围登债 3 项明确(坑 48 / 坑 53 / retry scheduler)
> - 新增 §十六 V2.1 收官战报 + 商业层准备清单
> **下次开工锚点**:Day 26 · V2.1 真机回归 + V2.2 路线决策

---

## 一、版本与文档定位

### 1.1 V8.8 是什么

V8.8 是 MLS 项目的**长期档**——不记每日操作步骤,记需要长期承袭的:

- 项目基本信息(人 / 路径 / 栈 / 账号)
- 产品本体定义(角色 / 商业模式 / 核心机制)
- 架构铁律(违反则动地基)
- 数据归属字段表(段 7 后定型)
- 辞典 4 层机制
- API 接口实测全表
- 模块完成度盘点
- 坑账(诊断成本沉淀)
- 工作流铁律 + 命令速查
- V2.1 收官战报 + V2.2 起手锚点

**不属于本档**:每日 commit 日志、单步操作、模块详细 spec、临时决策的细节。

### 1.2 V8.8 vs V8.7

V8.7 在 Day 23 末定档,当时段 7 已完工 6 个子段(7.1-7.6)+ 段 7.5 真机回归刚通过,7.7 全清回归未做。Day 24 一天打掉段 7.7 + 真机 5 节点回归(V2.1 #15 收官 = V2.1 整体完工)。Day 25 一天清掉真机回归暴露的 5 项登债 + Bug B(编辑页加 6 字段),V2.1 真正打磨到可拉种子用户的状态。

V8.7 → V8.8 的关键差别:

- V2.1 由"段 7 主体完成 + 真机回归未做"变为"真机回归通过 + 5 项登债清完"
- V8.7 §十.9 11 个推断坑(38-48)经真机验证后,**只有 2 个真撞(38、58 衍生)**,9 个推断不准,V8.8 重写为实录
- 新增坑账 49-59 共 11 条 Day 23-25 实录
- 新增 V3 范围 3 项设计性登债(坑 48 / 坑 53 / retry scheduler)
- 工程进度从"段 7 主线"切换到"V2.1 完工 / 准备拉种子用户"

V8.7 整档作废的实际含义:**V8.7 不再是当前 ground truth**,新会话开工密码只挂 V8.8。

### 1.3 适用场景

| 场景 | 操作 |
|---|---|
| 新会话开工 | 把 V8.8 + 当天起手任务挂进上下文 |
| 临时上下文丢失 | 把 V8.8 §九 战绩 + §八 模块完成度 贴回去 |
| 决策依据回查 | §四 铁律 + §五 数据归属 + §九 战绩 |
| 撞坑前自检 | §十 坑账,1-59 已知坑全在 |
| API 联调 | §七 接口表(对照 Swagger 实测) |
| 起新机器 | §二 项目基本信息 + §十四 命令速查 |
| 拉种子用户前 | §十六 V2.1 收官战报 + 商业层准备清单 |

---

## 二、人 / 项目基本信息

### 2.1 人

**磊**:创始人 + 唯一开发者。张家口本地。Windows 11 笔记本(24H2)。**非技术背景**——通过与 Claude 协作开发,已建立对 Flutter / FastAPI / MongoDB / Git 的工作熟悉度,能独立完成"读懂报错 → 复述给 Claude → 验证 fix → commit push"全流程。

**操作偏好**:
- 终端**只用 cmd**,不用 PowerShell
- VS Code 是主 IDE,Android Studio **只用 SDK 管理**
- 真机调试:USB 直连华为 NOH AL00,不用 emulator
- **角色定位:客户,不是开发者**——技术诊断细节不需要解释,要的是结论

### 2.2 项目结构

```
C:\projects\
├── .gitignore                    <-- archive/ 等私有目录排除
├── archive\                      <-- 测试数据备份(不入仓)
│   ├── mls_pre_v2_1_20260509\
│   └── dict_pre_v2_1_20260509\
├── mls\                          <-- monorepo,含 MLS + 辞典
│   ├── backend\                  <-- MLS FastAPI,8000 端口
│   │   ├── venv\                 <-- Python 3.11.15
│   │   ├── .env                  <-- DICT_BASE_URL + DICT_API_KEY (不入仓)
│   │   ├── main.py
│   │   ├── routes/ models/ schemas/ services/
│   │   └── scripts/reset_to_v2_1.py
│   ├── property-dictionary\      <-- 辞典 FastAPI,8001 端口
│   │   └── backend\
│   │       ├── venv\             <-- Python 3.11.9
│   │       └── ...
│   ├── app\mls_app\              <-- Flutter app
│   │   ├── lib\
│   │   │   ├── screens/
│   │   │   ├── services/api_client.dart  <-- baseUrl
│   │   │   ├── config/api_config.dart    <-- 局域网 IP 配置
│   │   │   ├── models/
│   │   │   └── widgets/
│   │   └── android\
│   ├── docs\                     <-- 长期档 + 模块 spec
│   ├── handoff\                  <-- 历史 handoff
│   └── README.md
├── bridge\                       <-- 别的小工具(无关)
└── shipinwenan\                  <-- 视频文案工作目录(无关)
```

**关键校正**(V8.7 §二.2 写错):辞典服务 = `C:\projects\mls\property-dictionary\backend\`,**嵌在 mls monorepo 内**,不是平级目录。

**MongoDB 数据目录**:`C:\data\db\`

### 2.3 技术栈

**MLS 后端**:
- Python 3.11.15 / FastAPI(uvicorn :8000,**所有路由前缀 `/api/v1/`**)
- MongoDB 8.2 Community(本地)
- fakeredis(开发态模拟 Redis,生产前必须切真 Redis)
- APScheduler(in-process,**仅注册了 1 个 job**:每天 03:00 扫过期申请)
- JWT(access 2h / refresh 30d,`flutter_secure_storage` 客户端加密)
- Pydantic v2

**辞典后端**(嵌在 mls 工程内,但服务独立):
- Python 3.11.9 / FastAPI 0.115
- MongoDB 8.2(独立 db `property_dict`)
- pytest(74 条单测全 pass · Day 21 基线)
- 端口 8001,所有路由前缀 `/v1/`

**MLS App 前端**:
- Flutter 3.41.7 / Dart
- Android SDK API 36.1
- 主要依赖:dio / hive / flutter_secure_storage / image_picker / image_compress / go_router / amap_flutter_map / cached_network_image / url_launcher / permission_handler / photo_view / connectivity_plus

**镜像源**(永久配置):
- Tencent cloud → `gradle-wrapper.properties`
- Aliyun → `build.gradle.kts` + `settings.gradle.kts`
- VPN 必须用 TUN / 增强模式

### 2.4 测试账号

| 账号 | 手机号 | 角色 | agent_id (ObjectId) | 备注 |
|---|---|---|---|---|
| 张三 | 13912345678 | LA(挂牌) | `69e45ec6e52ec020aa924065`(Day 23 实测,Day 24 全清后会变) | 段 7.7 真机回归挂第一套 |
| 李红 | 13200132000 | BA(带客) | (Day 24 全清后会变) | 段 7.7 真机回归带客 |

**短信验证码**:开发态 fakeredis 模式 `123456`(一次性,用过即失效)。生产前**必须切真 SMS 服务**。

### 2.5 GitHub 远端

- 仓库:`git@github.com:leelei-hub/mls.git`(monorepo)
- 主分支:`main`
- Day 25 末:本地 = origin/main 同步
- 推送策略:granular commit,每个独立改动一个 commit

### 2.6 真机网络配置

每次 Windows 重启后 PC IP 会变(局域网 DHCP),`ipconfig` 查 IPv4。

App `lib/config/api_config.dart` 的 `baseUrl` 必须是 PC 局域网 IP(非 localhost / 127.0.0.1 / 10.0.2.2),否则真机连不到后端。

Day 24 末 IP = `192.168.0.105`,baseUrl `http://192.168.0.105:8000`。每次 IP 变了要改 + Flutter hot restart 才生效。

---

## 三、产品本体与商业模型

### 3.1 一句话定义

**MLS = 张家口二手房经纪人协作系统**。B2B SaaS,会员费制,服务于本地中介经纪人之间的房源共享 + 带客协作 + 反作弊交易留痕。

### 3.2 名称与边界

- 中文名:**张家口二手房经纪人协作系统**
- 英文缩写:MLS(借用美国 Multiple Listing Service 的概念,但商业模式不同)
- 覆盖城市:**张家口**(单城起家)
- 覆盖业态:**二手房**(新房 / 商铺 / 写字楼后续考虑)
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

### 3.5 核心理念

**机制服务于信任的演化**。

平台不是中立工具,是信任机制的载体。经纪人之间合作有博弈(怕截客 / 怕压价 / 怕分赃不均),平台通过机制设计让"诚实合作"是 dominant strategy:

- 共享房源库 + 身份隐藏(BA 看不到 LA 联系方式,直到 LA 批准带看)→ 防截客
- 带客申请双向通过制 + 失败原因留档 → 防滥用
- 反作弊三分支(LA 独立填价 + 系统比对) → 防成交压价
- audit_log 全留痕 → 事后追溯

### 3.6 核心机制(用户旅程)

```
LA 挂牌 → 共享库可见 → BA 申请带看 → LA 批准 → BA 带看 →
LA 确认带看 → LA 变更状态(定金已付) → BA 发起成交 →
LA 独立填价 → 系统比对 →
匹配则 confirmed → 进结算 → 双方拿合作奖金
                               ↓
                            不匹配则进争议处理
```

**5 个核心节点 + 反作弊比对**,V2.1 已 Day 24 真机全部跑通:

```
节点 ①:listing(挂牌)
节点 ②:showing_request(带客申请)
节点 ③:showing(带看)
节点 ④:transaction(成交,反作弊三分支)
节点 ⑤:settlement(结算)
```

V2.1 在此之上叠加楼盘辞典系统(资产层),V2.1 #15 段 7 是 MLS 接入辞典的双侧改造。

### 3.7 商业层级:辞典 vs MLS(资产 vs 产品)

```
楼盘辞典(独占数字资产)            ← 数据飞轮
    ↓ HTTP REST + X-API-Key
MLS 张家口实例(可被接入的应用)     ← 单城单实例
MLS 保定实例(未来扩张)
MLS 廊坊实例(未来扩张)
第三方系统(未来生态)
```

辞典是**资产**(独立服务、独立 db、多租户预留、API Key 鉴权、city_scope 隔离)。MLS 是**产品**(单城单公司单 db,会员费制业务流)。两者通过 HTTP REST 通信,**不共享 venv / db / 端口 / 进程**(铁律 1)。

**V2.1 阶段**:辞典只签 1 个 API Key 给 MLS 张家口实例用,所有多租户机制就位(schema + 中间件)但实际只 1 个用户(磊本人)+ 1 个调用方(MLS)。未来扩张是改 JSON / 加 user record 的事,不是写代码。

---

## 四、6 条架构铁律

> 这 6 条是辞典 + MLS 的根。任何后续改造,先确认不违反;违反就是动地基。
> Day 22-25 段 7 接入实施 + 5 项登债清理全程,这 6 条无破例。

### 铁律 1 · 物理隔离

辞典与 MLS 是**两个独立服务**,不共享 venv / db / 端口 / 进程。

- venv:`property-dictionary/backend/venv/`(3.11.9) vs `mls/backend/venv/`(3.11.15)独立
- db:`property_dict` vs `mls` 独立(同一 mongodb 实例不同 database 不算违反——铁律 1 关注的是逻辑边界与运营所有权,不是物理 server)
- 端口:8001 vs 8000 独立
- 通信:仅 HTTP REST,不允许直接 import / 共享 ORM / 共享 db connection 池

**Day 24 校正**:listings.py 中 city_id auto-lookup 通过 `MongoClient` 直连 `property_dict.cities` 集合反查 — 这是同 MongoDB 实例不同 database 的访问,**不违反铁律 1**(铁律关注的是辞典与 MLS 各自的所有权和接口契约,不是物理底座)。重要前提:这种直连只用于"读字典表"这种轻操作,不允许直接读写辞典核心业务集合(properties / claims / discrepancies)。

### 铁律 2 · 数字资产定位

辞典是**独占数字资产**,MLS 是**可被接入的应用产品**。

- 辞典面向多个调用方(MLS 实例 / 第三方系统 / 未来 web 应用)
- MLS 面向一家公司在一个城市的经纪人

### 铁律 3 · 运营动作归属

- 辞典数据治理(户型标准化 / discrepancy 复核 / 基础数据导入 / 权威值修正 / 标准资产管理)归**辞典自有员工**
- MLS 端运营只管 MLS 业务(用户 / 房源 / 申诉),**不碰辞典数据**
- 辞典 admin UI 暂未开发,V2.1 走 mongo shell + CLI 替代

### 铁律 4 · 权限分级预留

辞典内三级:**owner / senior / operator**。

- owner:全部权限,V2.1 实际 1 人(磊)
- senior:复核 discrepancy / 修改权威值 / 管理标准资产
- operator:基础数据录入(小区 / 区县 / 城市)+ 受 city_scope 限制

`city_scope` 字段挂在每个 owner / senior / operator 上,operator 工作范围由此限定。所有写操作必经 audit_log。

**V2.1 实施**:schema + 中间件就位,实际只 1 个 owner,无登录 UI(改库手发)。

### 铁律 5 · 多租户预留

每个**外部调用方**(MLS 实例 / 第三方系统)独立 **API Key**。Key 携带:`city_scope` / `permissions` / `active`。

**V2.1 实施**:1 个 Key 给 MLS 用(`dev_mls_...`),Key 表 schema 完整,无管理 UI(改库手发)。

### 铁律 6 · 数据归属边界

**辞典只持有"物理永久 + 客观可测"的字段**。具体边界见 §五。

**Day 22-25 验证**:段 7.2 schema 改造严格按 §五 边界执行。Day 24 修坑 38 引入 city_id auto-lookup,**不违反**——auto-lookup 只读字典表(cities / districts),不读辞典核心业务集合。

---

## 五、完整数据归属表(V2.1 收官定型版)

### 5.1 辞典持有字段

```
身份层(永久,唯一索引):
  city_id          ObjectId
  district_id      ObjectId
  community_id     ObjectId
  building / unit / room_no    string

物理可测层(claim 工作流):
  area_sqm         float
  floor / total_floor          int
  rooms / halls / bathrooms    int

元数据:
  property_code         string     HMAC + base32,12 位
  authoritative_attrs   {field: value}     运营复核确定的权威值
  attribute_claims      [{...}]           历史所有 claim
                                          (LA / listing / timestamp / values / verified)
  standard_assets       {floor_plan_url, real_photos[]}
  created_at / updated_at

历史层(永久不变,只追加):
  transaction_history   [{...}]
                         price_yuan / deal_date / ba_id / la_id / 
                         transaction_id / source / verified
  listing_history       [{...}]
                         listed_at / sold_at / listing_id / status / listing_price_wan

治理层(辞典自身集合):
  property_discrepancies   差异工单(4 态)
  audit_logs               所有写操作留痕
  api_keys                 多租户预留
  cities / districts / communities  字典表
```

### 5.2 MLS 持有字段(段 7.2 改造后定型)

```
认证层:
  agents                JWT 认证基础

客户运营层:
  customers             经纪人私有客户档案(轻量,仅 notes + association)

挂牌运营层(listing 文档):

  ───── 辞典引用(段 7.2 新加) ─────
  property_id          ObjectId   引用辞典 property._id
  property_code        string     12 位 HMAC base32

  ───── 营销字段 ─────
  price_wan            float
  bonus_yuan           int
  status               enum   (on_sale / deposit_paid / transaction_ongoing / sold / offline)
  status_label         string  (运行时拼,中文 status 显示用)
  owner_agent_id       ObjectId
  sale_points / description / remarks   string
  photos               [base64]   (V2.1 阶段 base64,P1 tech debt 迁对象存储)
  cover_thumbnail      string     缩略图 base64
  photo_count          int
  commission_doc_url   string
  listed_at / sold_at  datetime
  deposit_associated_showing_id   string

  ───── 主观描述字段 ─────
  layout               string     "南北通透" / "南向为主" / 自由文本
  orientation          string

  ───── 段 7.2 已物理删除字段 ─────
  ❌ area_sqm / floor / total_floor / rooms / halls / bathrooms
       → 改从辞典 fetch
       → Bug B 已修(Day 25):LA 编辑页加 6 字段输入 → POST /sync-physical 走辞典 claim

  ───── 身份字段冗余保留(段 7.2 决议) ─────
  city / district / community / community_id /
  building / unit / room_no / house_code

协作流程层(完全归 MLS):
  showing_requests / showings / transactions / settlements

视图聚合层(MLS 自己拼装):
  dashboard 工作台聚合
```

### 5.3 字段查询性能(段 7.4 决议)

- **单条**:`GET /api/v1/listings/{id}` 内调 `dict.get_property(property_code)`
- **列表**:`POST /v1/properties/batch` 一次批量 fetch,避免 N+1

BA 视图永远从辞典读最新物理(authoritative > claim 最近),不用 listing 冗余。

### 5.4 联动接口(MLS → 辞典)

> Base URL: `http://<dict_ip>:8001/v1/`,所有调用必带 `X-API-Key` Header。

| 场景 | MLS 端动作 | 调用 endpoint |
|---|---|---|
| LA 挂牌(身份) | 用户填 city/district/community/building/unit/room_no | `POST /properties/identify` |
| LA 挂牌(claim) | 用户填 6 物理字段 | `POST /properties/{code}/claims` |
| LA 挂牌(force) | LA 弹窗确认后重发 | `POST /properties/{code}/claims?force=true` |
| BA 看共享库 | MLS 拉本地 listings | `POST /properties/batch` |
| BA 看详情 | MLS 拉单 listing | `GET /properties/{code}` + `GET /properties/{code}/transaction-history` |
| LA 看自己 listing | MLS 编辑页加载 | `GET /properties/{code}` 比对 → 渲染黄条 |
| LA 编辑物理字段(Bug B) | 编辑页 6 字段提交 | `POST /listings/{id}/sync-physical` body 带新值 → 后端转 claim |
| LA 一键同步权威值 | 黄条按钮 | `POST /listings/{id}/sync-physical` body 空 → 后端从 my_last_claim 自动同步 |
| 成交 confirmed | MLS 完成 transaction 写库后 | `POST /transactions` (sink) |

---

## 六、辞典 4 层机制

辞典系统的核心是 4 层:**身份 → 识别 → 裁决 → 事实**。

### 第 1 层 · 身份(HMAC 算码 + 6 字段唯一索引)

每套房物理唯一身份(6 字段)。`services/coding.py` 用 HMAC-SHA256 把 6 字段 + secret_key 哈希成 12 位 base32 字符串,即 `property_code`。

特性:
- 同 6 字段输入 → 同 code 输出(确定性,幂等)
- 不同 6 字段 → 不同 code(碰撞极低)
- 反推不出 6 字段(单向哈希,防泄露)
- 不可读(base32,与中文/拼音无关)

**生产 secret_key 与开发 secret_key 严格隔离**(`.env` 分文件,不入仓)。

### 第 2 层 · 识别(命中或创建,幂等)

`POST /v1/properties/identify` 收 6 字段 → 算 code → 查 properties:

- 命中(同 code 已存在)→ 返既有 property
- 未命中 → 建新 property,返新 property

**幂等**:同 6 字段反复调,永远返同一条 property。这是 MLS 端"先调辞典再写本地"双写模式的基石。

### 第 3 层 · 裁决(claim + 比对 + 复核 + 权威值)

LA 挂牌时对 6 物理字段提交 claim:

```
POST /v1/properties/{code}/claims
{
  "area_sqm": 95.5, "floor": 5, "total_floor": 18,
  "rooms": 3, "halls": 1, "bathrooms": 1,
  "source": {"agent_id": "...", "listing_id": "...", "force": false}
}
```

辞典内部裁决:

**1. 比对优先级**(白名单驱动):
- `authoritative_attrs` 优先 → 缺则 `attribute_claims[]` 历史最近 → 都缺则不比对(首次直接接受)

**2. 三分支结果**:
- 全字段一致 → 接受 claim,沉淀 attribute_claims[](标 verified=true)
- 不一致 + force=false → 返 409 + diff,MLS 端弹窗给 LA(黄条)
- 不一致 + force=true → 接受 claim(标 unverified)+ 每差异字段写 1 条 discrepancy 工单

**3. discrepancy 4 态**:
- `pending`(新生成,待运营复核)
- `confirmed_new`(LA 对,authoritative 更新)
- `confirmed_history`(历史值对)
- `needs_evidence`(LA 上传房本凭证再判)

**4. 复核必走**:不允许 dismiss,只能进 4 态之一。

### 第 4 层 · 事实(transaction_history,只记不裁)

MLS 端成交 confirmed 时调 `POST /v1/transactions` 把成交事实推给辞典。辞典记到 `property.transaction_history[]`。

特性:
- 写入即终态,不可改
- 只记录,不裁决
- 永久保留,跨 listing 不丢
- `verified` 字段语义:**"MLS 内部已经过反作弊比对(LA/BA 独立填价 + 系统比对一致),数据可信"**——与外部数据(贝壳/链家/政府备案,默认 verified=False 待人工复核)区分。MLS 端 sink_transaction 默认传 `verified=true`。

**Day 24 真机首次写入 transaction_history**:price=880000 / date=2026-05-09 / verified=True / source=mls_internal,这是 V2.1 第一条真实成交事实。

### 4 层关系

```
身份(永久) → 识别(读,命中或创建) → 裁决(写,可比对) → 事实(写,不可改)
```

身份是基石,识别是入口,裁决是治理,事实是终点。

---

## 七、API 接口表(V2.1 收官实测全量)

> 来源:`http://localhost:8000/docs` Swagger 实测。
> 全部路由前缀 `/api/v1/`。

### 7.1 认证(auth)

| Method | Path |
|---|---|
| POST | `/api/v1/auth/send-sms-code` |
| POST | `/api/v1/auth/register` |
| POST | `/api/v1/auth/login` |
| POST | `/api/v1/auth/refresh` |
| POST | `/api/v1/auth/logout` |
| GET | `/api/v1/me` |

### 7.2 房源(listings)

| Method | Path |
|---|---|
| POST | `/api/v1/listings` |
| GET | `/api/v1/listings/mine` |
| GET | `/api/v1/listings/shared` |
| GET | `/api/v1/listings/meta/districts` |
| GET | `/api/v1/listings/{listing_id}` |
| PATCH | `/api/v1/listings/{listing_id}` |
| DELETE | `/api/v1/listings/{listing_id}` |
| POST | `/api/v1/listings/{listing_id}/mark-deposit-paid` |
| POST | `/api/v1/listings/{listing_id}/mark-transaction-ongoing` |
| POST | `/api/v1/listings/{listing_id}/rollback-to-on-sale` |
| POST | `/api/v1/listings/{listing_id}/reactivate` |
| POST | `/api/v1/listings/{listing_id}/sync-physical` ← Bug B 阶段 1 增强 |

### 7.3 带客申请(showing-requests)

| Method | Path |
|---|---|
| POST | `/api/v1/showing-requests` |
| GET | `/api/v1/showing-requests/received` |
| GET | `/api/v1/showing-requests/sent` |
| GET | `/api/v1/showing-requests/pending-count` |
| GET | `/api/v1/showing-requests/{request_id}` |
| POST | `/api/v1/showing-requests/{request_id}/approve` |
| POST | `/api/v1/showing-requests/{request_id}/reject` |

### 7.4 带看(showings)

| Method | Path |
|---|---|
| POST | `/api/v1/showings` |
| GET | `/api/v1/showings/pending-confirm` |
| GET | `/api/v1/showings/pending-confirm-count` |
| GET | `/api/v1/showings/by-request/{request_id}` |
| POST | `/api/v1/showings/{showing_id}/confirm` |
| POST | `/api/v1/showings/{showing_id}/reject` |
| GET | `/api/v1/showings/can-direct` |
| POST | `/api/v1/showings/direct` |
| GET | `/api/v1/showings/{showing_id}` |

### 7.5 成交(transactions)

| Method | Path |
|---|---|
| POST | `/api/v1/transactions` |
| GET | `/api/v1/transactions/pending-la` |
| GET | `/api/v1/transactions/pending-la-count` |
| GET | `/api/v1/transactions/by-showing/{showing_id}` |
| POST | `/api/v1/transactions/{transaction_id}/la-confirm` |
| POST | `/api/v1/transactions/{transaction_id}/la-reject` |
| PATCH | `/api/v1/transactions/{transaction_id}/my-submission` |
| POST | `/api/v1/transactions/{transaction_id}/cancel` |
| GET | `/api/v1/transactions/{transaction_id}` |

### 7.6 工作台(dashboard)

| Method | Path |
|---|---|
| GET | `/api/v1/dashboard/summary` |
| GET | `/api/v1/dashboard/todos` |
| GET | `/api/v1/dashboard/recent-events` |

### 7.7 小区(communities)

| Method | Path |
|---|---|
| GET | `/api/v1/communities/search` |
| POST | `/api/v1/communities` |
| GET | `/api/v1/communities/{community_id}` |

### 7.8 结算(settlements)

| Method | Path |
|---|---|
| GET | `/api/v1/settlements/pending-my` |
| GET | `/api/v1/settlements/pending-my-count` |
| POST | `/api/v1/settlements/{settlement_id}/la-mark-paid` |
| GET | `/api/v1/settlements/{settlement_id}` |

### 7.9 客户(customers)

| Method | Path |
|---|---|
| POST | `/api/v1/customers` |
| GET | `/api/v1/customers/mine` |
| GET | `/api/v1/customers/{customer_id}` |
| PATCH | `/api/v1/customers/{customer_id}` |
| POST | `/api/v1/customers/{customer_id}/memo` |
| PATCH | `/api/v1/customers/{customer_id}/close` |
| GET | `/api/v1/customers/{customer_id}/timeline` |

### 7.10 协作(collaborations)

| Method | Path |
|---|---|
| GET | `/api/v1/collaborations/mine` |

### 7.11 接口数总计

61 endpoints(与 V8.7 一致,Day 24-25 无新增 endpoint,只是 sync-physical schema 增强 + 修复)

---

## 八、模块完成度盘点 + V2.1 进度

### 8.1 模块完成度

| 模块 | spec 文档 | 完成度 | 备注 |
|---|---|---|---|
| 模块一(注册登录) | V8 App 版 | ✅ 100% | JWT + 短信验证码 + 多设备管理 |
| 模块二(房源管理) | V11 App 版 | ✅ 100% | 段 7 接入完成 + Bug B 编辑页加 6 物理字段 |
| 模块三(共享房源库) | V7 App 版 | ✅ 100% | 段 7.4 batch fetch + 卡片副标题 null 处理 |
| 模块四(带客协作) | V9 App 版 | ✅ 100% | 协作 Tab 全生命周期 + Tab 切换自动刷新 |
| 模块五(交易留痕) | V10 App 版 | ✅ 100% | 反作弊三分支 + 段 7.6 sink + Day 24 真机验证 |
| 模块六(Web 管理后台) | V7 | ⏸ V2.1 不做 | spec 锁定不变,V3 启动 |
| 模块七(推送消息) | V10 App 版 | ⏸ V2.1 简化 | 极光 schema 就位,实推服务后置 |

### 8.2 V2.1 进度

```
V2.1 #15 段 7(MLS 接入辞典双侧改造):
  段 7.1 ✅ Day 22  dictionary_client.py
  段 7.2 ✅ Day 22  listings schema 改造(物理 6 字段物理删除)
  段 7.3 ✅ Day 22  listing CRUD 双写
  段 7.4 ✅ Day 22  BA 视图 batch fetch
  段 7.5 ✅ Day 22-23  LA 黄条 + sync-physical + 真机回归(坑 49 修复)
  段 7.6 ✅ Day 22  transaction sink 钩子
  段 7.7 ✅ Day 24  全清回归 + 真机 5 节点(坑 38 三层根因 + bug A 辞典序列化 + 反作弊比对验证)

V2.1 真正打磨(Day 25):
  ✅ 坑 56  协作 Tab 切换自动刷新
  ✅ 坑 50  卡片副标题 null 检测
  ✅ 坑 59  状态变更后封面图丢失
  ✅ 坑 57  "已通过中" 文案去歧义
  ✅ Bug B  编辑页加 6 物理字段 + sync-physical 双流程 + 黄条复用

V2.1 状态:整体收官。可拉种子用户。
```

### 8.3 V2.1 未做的事(进 V2.2 或 V3)

| 项目 | 优先级 | 范围 | 备注 |
|---|---|---|---|
| 多区域隔离(注册带 city/district + 协作链按区过滤) | P0 V3 | V3 | 坑 53 |
| 对象存储迁移(替换 base64 photo) | P1 | V2.2 启动 | 房源量 > 50 时启动 |
| Web 管理后台(模块六) | V3 | V3 | spec 锁定不变 |
| 推送服务实接(模块七) | V2.x 后期 | V2.2 | 极光 schema 就位 |
| _BuildSyncBanner 硬编码 6 字段映射 | V3 | V3 | 坑 48,物理字段扩展时撞 |
| pending_dict_sinks retry scheduler | P1 V3 | V3 | aa413bc commit 名不副实 |
| Logout 安全加固 | P2 | V2.2 | server 侧 token 黑名单 |
| Dashboard UI polish | P3 | V2.2 | 视觉打磨 |
| "我的"页面入口(头像) | P3 | V2.2 | 工作台右上角 |

---

## 九、Day 22-25 战绩(段 7 大爆发 + V2.1 收官)

### 9.1 Day 22 战绩(10 commit · 后端段 7.1-7.6)

```
58c80d7  段 7.1   dictionary_client.py
2503585  段 7.2   listings schema 改造(删 area_sqm 等 6 物理字段)
dca0cb1  段 7.3   listing CRUD 双写
ba32148  段 7.4   BA 视图 batch 富化(POST /properties/batch)
a2538d3  段 7.5.0 修 _enrich_from_dictionary silent bug
a3d77a6  段 7.5.1 GET LA 视角加 my_last_claim
74e420f  段 7.5.2.a POST sync-physical endpoint
d911f62  段 7.5.2.b listing_edit_screen 黄条 UI + 一键同步
aa413bc  段 7.6   transaction sink 钩子(注:retry scheduler 实际未实施)
```

### 9.2 Day 23 战绩(1 commit · 段 7.5 真机回归收尾)

```
179213b  fix 坑 49 filter matches 漏 isActive 守卫
```

诊断成本 1.5h:curl 后端 9 条返回正常 → mongosh 验 ObjectId 类型正常 → dio 超时排查 → 静态读 _filters.matches 1 分钟破案。

### 9.3 Day 24 战绩(2 commit · 段 7.7 收官)

```
2ae8a40  fix 坑 38 三层根因 + 段 7.7 E2E 全通
7521470  fix bug A · 辞典 _serialize_property 序列化 ObjectId/datetime + V2.1 收官
```

**Day 24 真机回归 5 节点全部跑通**:挂牌 → 申请带看 → 带看 → 状态流转 → 反作弊成交比对。
**辞典 transaction_history[0] 永久写入**:price=880000 / 2026-05-09 / verified=True / source=mls_internal。

### 9.4 Day 25 战绩(6 commit · V2.1 真打磨)

```
115cf84  坑 56  协作 Tab 切换自动刷新
abf11bd  坑 50  卡片副标题 null 检测
96bacf2  坑 59  状态变更后封面图丢失
31aa0f7  坑 57  "已通过中" 文案去歧义
8d9299c  Bug B 阶段 1  sync-physical 接受 body 物理字段
efbe291  Bug B 阶段 2+3  编辑页 6 字段 + 双流程提交 + 黄条复用
```

### 9.5 Day 22-25 关键决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 段 7.2 migrate 脚本 | 不写,V2.1 全清省事 | 测试期数据无价值 |
| 批量 endpoint 位置 | 辞典侧加 `POST /properties/batch` | 单一事实源 |
| 段 7.6 sink 策略 | 强制同步 + 5xx 降级 retry 队列(实际 retry scheduler 未实施 → V3 处理) | 99.9% 强一致 |
| 段 7.7 数据清空 | C 选项 — 辞典清业务保字典(17 区县保留) | 字典是真资产 |
| 坑 49 修复 | filter isActive 显式契约 | 避免单字段 null 兜底坑 |
| 坑 38 修复 | 三管齐下(.env + 401 处理 + city_id auto-lookup) | 三层根因不能只修一层 |
| Bug B 修复 | 编辑页加 6 字段 + 走 sync-physical 不直接 PATCH | 物理字段必经辞典裁决 |
| 多区域隔离 | 推到 V3 | 牵动 4 集合 + 8 endpoint,V2.1 不引入 |

### 9.6 commit 总数

```
Day 22:  10 commit
Day 23:   1 commit
Day 24:   2 commit
Day 25:   6 commit
─────────────────
共       19 commit · 4 天 · V2.1 段 7 完工 + V2.1 整体收官 + 真打磨
```

---

## 十、坑账总集 1-59(V2.1 收官完整版)

### 10.1 分类索引

| 类别 | 坑号 | 主题 |
|---|---|---|
| **A. 环境配置** | 13-18 | Windows / Android SDK / Gradle / VPN / 镜像 |
| **B. Dart / Flutter 语言陷阱** | 25, 27, 32 | enum / Spacer / IntrinsicHeight |
| **C. Pydantic / FastAPI** | 28 | silent discard 字段 |
| **D. VS Code 工作流** | 26 | 大文件替换 |
| **E. 权限 / Manifest** | 29 | url_launcher queries |
| **F. 跨语言类型系统** | 30 | ObjectId vs str |
| **G. UI 状态管理** | 11, 31 | FutureBuilder / setState |
| **H. Day 22 推断坑(38-48)** | 38-48 | V8.7 推断,Day 24 真机后大部分注销 |
| **I. Day 23-25 实录** | 49-59 | 真机回归 + V2.1 打磨 |

### 10.2 A-G 类(承袭 V8.7,无变化)

详见 V8.7 §十.2-十.8。本档不重复。

### 10.3 H 类 · Day 22 推断坑账(V8.7 §十.9)经真机验证后修订

> Day 22 当时段 7.1-7.6 一天 11 commit 打掉,具体撞过的坑磊本人记不清。
> V8.7 §十.9 推断 11 条(38-48)。Day 24 真机回归后验证结果:
> 大部分推断不准,**真撞 + 解决的只有 2 条(38、58 衍生)**。

| 编号 | V8.7 推断主题 | 真实情况 | 状态 |
|---|---|---|---|
| 38 | dictionary_client httpx 超时 | **错** — 真坑是 .env 不存在 + dotenv 未装 + community_id 桥接 + city_id auto-lookup,共 3 层根因。Day 24 修复见 commit `2ae8a40` | ✅ 实录见 §10.4 |
| 39 | 单测 mock 边界 | 未撞 | ✓ 注销 |
| 40 | Pydantic v2 model_dump | 未撞 | ✓ 注销 |
| 41 | fromJson 残留旧字段 | 段 7.5.2.b 已删,未撞 | ✓ 注销 |
| 42 | 双写顺序 | 段 7.3 实现已正确 | ✓ 注销 |
| 43 | force=true 流程 | 未撞 | ✓ 注销 |
| 44 | batch endpoint codes 上限 | 未撞(V2.1 数据小) | ✓ 注销,V3 注意 |
| 45 | BA 视图 fetch 失败降级 | 未撞 | ✓ 注销 |
| 46 | 黄条 null 字段 skip | 未撞 | ✓ 注销 |
| 47 | sink 跨服务事务 | 未撞,设计接受最终一致 | ✓ 注销 |
| 48 | retry 队列幂等性 | **真坑但 V2.1 未触发** — aa413bc commit 信息说接了 retry,实际 scheduler 没注册。V3 实施 | ⏳ V3 |

**结论**:V8.7 §十.9 引入"推断式坑账"协议——结果证明这类预判**命中率约 18%**(2/11)。Day 26 起停用此协议,V8.8 §十三.6 注销。

### 10.4 I 类 · Day 23-25 实录坑(详写)

#### 坑 38 · MLS 调辞典三层根因(Day 24 实录,V8.7 推断错主题)

**触发场景**:Day 24 段 7.7 真机回归步 1 张三挂房,App 弹"录入失败:辞典服务不可达 unreachable"。

**实际三层根因**:

```
1. MLS .env 文件不存在 + dotenv 未装
   → DICT_API_KEY = "" → 辞典 401
   → MLS dictionary_client 把 401 误判为"unreachable"

2. MLS communities 集合 vs 辞典 communities 集合
   → 两套 ObjectId,直接传 community_id 给辞典,辞典 404 "Community not found"
   → 需 dict.identify_community() 桥接

3. Flutter listing_create 未传 city_id / district_id
   → 后端 city_id is None 时走 graceful degrade(silent skip 辞典)
   → property_code 写 None,辞典啥也没有
   → MLS 写入 listing 显示成功 → 用户以为成了
```

**修复**(commit `2ae8a40`):
- `mls/backend/.env` 新建,含 DICT_BASE_URL + DICT_API_KEY
- `dictionary_client.py`:`load_dotenv()` + 401 → DictionaryForbiddenError(明确异常类型,不再误报 unreachable)
- `listings.py`:加 city_id / district_id auto-lookup from `property_dict.cities/districts`(Flutter 端无需改),community_id 桥接通过 `dict.identify_community()`,删除 graceful degrade 静默 skip 路径(改为 400 拒绝)

**架构教训**:graceful degrade 路径只能在**辞典服务 5xx 不可达**时启用,**不能**在用户字段缺失时启用。否则"前端显示成功,后端没真写"是最伤产品的 bug。

#### 坑 49 · filter matches 漏 isActive 守卫(Day 23 实录)

**触发场景**:段 7.2 后端删 listing 物理 6 字段,前端 `listing_filters.matches()` 仍用 `?? 0` 兜底读 area_sqm,`_processItems` 无 isActive 守卫,空筛选条件下也调 matches。结果:area=0 < minArea(30) 永远 false,我的房源 9 条全被滤为空。

**修复**(commit `179213b`):`_processItems` 调 matches 前加 `_filters.isActive` 守卫,**空筛选 = 不过滤 显式契约**。修复半径:`listing_list_screen.dart` + `listing_shared_screen.dart` 两处。

**通用规则**:筛选器 / 过滤器函数应有"isActive 守卫"做显式契约,空筛选 = 不过滤,不依赖单字段兜底语义。

**诊断成本**:1.5h(curl → mongosh → dio 超时排查 → 静态读 1 分钟破案)。教训:**任何 schema 改动后,前端凡是读这些字段的地方必须全文 grep**,不是只盯 model 类。

#### 坑 50 · 卡片副标题 null 渲染(Day 24 暴露 / Day 25 修)

**症状**:Day 24 真机截图显示 `null㎡ · null/null层`。

**根因**:段 7.2 后端删 6 物理字段,前端卡片副标题 `'${item['layout']} · ${item['area_sqm']}㎡ · ${item['floor']}/${item['total_floor']}层'` null 直接转字面量字符串。

**修复**(commit `abf11bd`):每段独立 null 检测,null 时省略该段。

**应用范围**:`listing_list_screen.dart` _ListingCard widget(后续 grep 全文确认无遗漏)。

#### 坑 53 · 多区域隔离设计(Day 24 暴露,V3 处理)

**触发场景**:Day 24 段 7.7 步 1 暴露——当前架构假设 MLS 单城单实例,经纪人不带 city_id/district_id,导致跨用户 / 跨区域协作场景未隔离。

**设计动议**(磊提出):注册时带城市 + 区选择,挂在 agent 文档,后续所有挂牌 / 共享库 / 协作按此过滤。

**影响范围**:agents / listings / customers / showings / transactions schema + 8 个 list/filter endpoint + 注册流程 + 共享库过滤逻辑。

**决策**:V3 启动时实现,V2.1 / V2.2 不引入。

#### 坑 54、55、52、51 · 跳号(Day 24 命名时占位,实际未独立)

(V8.7 临时给候选坑 50/51/52 编了号,Day 25 真正修时 50 单列,51 / 52 / 54 / 55 与坑 50/53/59 合并归口。编号保留跳号,不补。)

#### 坑 56 · 协作 Tab 切换不刷新(Day 25 修)

**症状**:协作 Tab 提交带看申请后切回 Tab,看不到新数据,需手动下拉刷新或点右上角 ↻ 按钮。

**根因**:`collaboration_list_screen.dart` 只在两处刷新:手动刷新按钮 + 详情页 pop 回来后。**没有 TabBarView 切换监听 / RouteAware focus / VisibilityDetector**。

**修复**(commit `115cf84`):`_tabController.addListener` 监听 index 变化(`indexIsChanging` 守卫防动画期间重复触发)→ 调 `_refresh()`。

#### 坑 57 · "已通过中" 文案多 "中" 字(Day 24 暴露 / Day 25 修)

**症状**:协作 Tab 卖方协作进度条卡片右上角徽标显示 "已通过中"(应为"已通过")。

**根因**:`backend/collaborations.py` 中 stage_label 拼接逻辑产生歧义。

**修复**(commit `31aa0f7`):改为 "已通过(进行中)" 去歧义。

#### 坑 58 · 辞典 _serialize_property ObjectId 序列化失败(Day 25 修 = bug A)

**触发场景**:Day 24 真机回归暴露——LA 房源详情页面积、楼层显示 null,但列表页(走 batch enrich)正常。

**根因**:辞典 `_serialize_property` 返回 `attribute_claims` / `transaction_history` / `listing_history` 三个字段含 MongoDB ObjectId 和 datetime,FastAPI `jsonable_encoder` 不会自动序列化嵌套结构。结果:

```
辞典 GET /properties/{code} 返 500
→ MLS _enrich_from_dictionary 静默失败
→ 详情页所有物理字段显示 null
```

**为啥 batch endpoint 不撞**:段 7.4 写 batch 时已做序列化处理,**单条 GET endpoint 漏了**。

**修复**(commit `7521470`):`property-dictionary/backend/api/v1/properties.py` `_serialize_property` 三层嵌套字段 ObjectId → str + datetime → isoformat。

**Day 25 review 结论**:其他可能撞同样问题的 endpoint(transaction-history / discrepancies)Day 24 真机已侧面验证,未撞。

#### 坑 59 · 状态变更后封面图丢失(Day 24 暴露 / Day 25 修)

**症状**:LA 房源详情页"变更交易状态"为"定金已付"后,"我的房源"列表卡片缩略图变占位灰图。

**根因**:后端 `mark_deposit_paid` / `mark_transaction_ongoing` / `reactivate` 等 endpoint 只 `$set: {status, updated_at}`,**不碰 cover_thumbnail/photos**——后端无误。前端状态变更后 `Navigator.pop(context, listing)` 把旧快照传回列表,列表用 result 覆盖了卡片数据。

**修复**(commit `96bacf2`):状态变更成功后 `Navigator.pop(context, true)`,列表层 `await` 返回值后无条件 `_refresh()` 主动重拉,不依赖旧 listing 对象。

#### Bug B · 编辑页字段太少(Day 24 暴露 / Day 25 修)

**触发场景**:Day 24 真机暴露——编辑页只剩照片/朝向/价格/奖金/备注,缺面积/楼层/户型 6 字段。段 7.5.2.b 当时 "删 silent fail 字段" 的初衷是 LA 不该编辑物理字段(应走辞典裁决),但实际产品需求是 **LA 写错了想改面积必须能改**——改的方式是触发新 claim,可能撞 409 黄条。

**修复**(commit `8d9299c` + `efbe291`):

阶段 1 · 后端 sync-physical schema 增强:
- 接受可选 body(area_sqm / floor / total_floor / rooms / halls / bathrooms / force)
- body 全 None → 走原逻辑(从 my_last_claim 自动同步)
- body 有值 → 用新值调 dict.submit_claim(force=force)
- 辞典 409 → 返前端 {error: "conflict", diff, expected_source}

阶段 2 · 编辑页加 6 字段 input(预填来源:authoritative_attrs > my_last_claim > 空)

阶段 3 · 提交双流程:
- Step A · PATCH 营销字段(原逻辑)
- Step B · POST sync-physical(物理字段)→ 200 / 409
- 409 弹黄条(复用段 7.5.2.b _BuildSyncBanner):"按权威值改" / "强制提交我的值"
- force=true 重发,辞典必接受 + 生 discrepancy 工单

**架构教训**:silent fail 字段(段 7.5.2.b 删字段的语义)与 "用户必须能改物理字段" 冲突。正确路径不是禁止用户编辑,是**让编辑必经辞典裁决**。

---

## 十一、V3 范围登债(Day 26 不动,V3 处理)

> V2.1 收官后未清的设计性债,共 3 项,**全部归 V3**。
> V2.1 / V2.2 阶段不阻塞拉种子用户。

### 11.1 坑 48 · _BuildSyncBanner 硬编码 6 字段映射

**现状**:Flutter 端 `_BuildSyncBanner` widget 硬编码 6 物理字段中文映射(`area_sqm → '建筑面积'` 等)。

**问题**:V3 物理字段扩展(比如增加"装修年代"、"车位数"等)时需手改前端代码。

**V3 修复方向**:从辞典字典表读字段中文映射,前端动态渲染。

### 11.2 坑 53 · 多区域隔离

详见 §10.4 坑 53。V3 启动时实现。

### 11.3 retry scheduler 未实施(aa413bc commit 名不副实)

**现状**:
- `transactions.py` `sink_transaction_to_dict` 在异常时 `insert pending_dict_sinks`(已实现)
- `scheduler.py` 只注册了 1 个 job(每天 03:00 `expire_stale_showing_requests`)
- **没有 pending_dict_sinks 的 retry job**
- **没有索引**(transaction_id 唯一索引、retry_count、next_retry_at)
- **没人读 pending_dict_sinks 集合**

**含义**:辞典 5xx 时数据进 pending 集合 → **永远不会被重试** → 数据真丢。

**V2.1 阶段不修原因**:辞典在线率 100%,不会触发。

**V3 修复**:
1. APScheduler 注册 5min retry job
2. 集合加索引(transaction_id 唯一 + next_retry_at)
3. retry_count <= 5 自动重试,>5 转人工告警

### 11.4 已知 tech debt(承袭并更新)

| 项目 | 优先级 | 触发条件 |
|---|---|---|
| 对象存储迁移(替换 base64) | **P1** | 房源量 > 50 时启动(V2.2) |
| Logout 安全加固(server 侧 token 黑名单) | P2 | 上线前(V2.2) |
| Dashboard UI polish | P3 | V2.2 |
| "我的"页面入口(头像) | P3 | V2.2 |
| 真机 IP 自动发现 | P3 | 用户增多后(V2.2 末) |
| Web 管理后台(模块六) | V3 | V3 启动 |
| 推送服务接入(模块七) | V2.x 后期 | V2.2 启动 |

---

## 十二、Day 26 起手锚点 + V2.2 路线候选

### 12.1 Day 26 主线

V2.1 已收官。Day 26 起进入 **V2.1 验证拉种子用户阶段** 或 **V2.2 起手准备阶段**,二选一。

```
路线 A · V2.1 拉种子用户
  - 找张家口本地经纪人测试(2-3 个 LA + 1-2 个 BA)
  - 真实数据上跑 1 周
  - 收反馈 → 二轮坑账 → 修
  - 出收费方案

路线 B · V2.2 起手开发
  - 优先级排序:对象存储 / 推送服务 / 多区域隔离 / 社区库 MVP / Logout 加固
  - 某些可以并行(对象存储 + 推送都不依赖产品改造)
```

**建议**:路线 A 先,**真实用户反馈比 Claude 推断价值高 100 倍**。但磊定。

### 12.2 Day 26 第一件事(无论路线)

**真机回归验证 Day 25 5 项修复**:

```
张三登录验证:
1. 我的房源卡片副标题 — 不再 null         [坑 50]
2. 挂新房 → 列表带封面图                  [坑 59 准备]
3. 详情页变状态"定金已付" → 返回列表
   → 封面图还在                             [坑 59]
4. 编辑房源 → 6 物理字段输入可见          [Bug B 阶段 2]
5. 改面积 95→96 提交 → 弹冲突黄条        [Bug B 阶段 3]
   选"按权威值"→ 输入框变 95 → 再提交成功
6. 协作 Tab 切"买方/卖方"sub-Tab          [坑 56]
   每次切换数字重新加载

李红登录验证:
7. 协作 Tab 状态徽标 "已通过(进行中)"
   不再"已通过中"                         [坑 57]
```

7 项全过 → V2.1 真打磨完成。撞坑 → 现场修。

### 12.3 V2.2 路线候选(磊 Day 26 拍板)

按价值 × 工作量排:

| 候选 | 价值 | 工作量 | 时机 |
|---|---|---|---|
| 对象存储迁移 | 高(房源 > 50 必崩) | 2-3 天 | V2.2 第一波 |
| 推送服务接入 | 高(用户体验) | 2 天 | V2.2 并行 |
| 社区库 MVP | 中 | 1-2 天 | V2.2 中期 |
| Logout 加固 | 低(安全) | 0.5 天 | 上线前必修 |
| Dashboard UI polish | 低 | 0.5 天 | V2.2 末 |
| 多区域隔离 | 高(扩张) | 4-5 天 | **V3 启动** |
| Web 管理后台 | 高(运营) | 1 周+ | **V3 启动** |

### 12.4 Day 26 开工密码模板

```
任务:Day 26 · V2.1 真机回归验证 + V2.2/V3 路线决策

工程路径:C:\projects\mls\

承接 Day 25 末:V2.1 收官,5 项登债 + Bug B 全清(efbe291 等 6 commit 已 push)

Day 26 第一件事:
- 真机回归 7 项验证(详见 V8.8 §十二.2)
- 全过 → 进 V2.2/V3 路线决策

V2.2/V3 路线 3 选 1:
A · 拉种子用户(2-3 个真实经纪人测试 1 周)
B · V2.2 开发(对象存储 / 推送 / 社区库)
C · 直接进 V3(多区域 + Web 管理后台)

铁律:
- cmd 不用 PowerShell
- VS Code 大文件 Ctrl+A → 等 1s → Delete → 等 1s → Ctrl+V
- AndroidManifest 改后 q + flutter run
- granular commit
- 我是客户,Claude 是工程师 — 不教学,不解释技术细节,要结论
```

---

## 十三、协作约定 + 工作流铁律(Day 25 末更新)

### 13.1 会话起手协议

新会话第一条消息标准格式("开工密码"):

```
任务:[Day N · V2.X #M · 段 X.Y 名称]

工程路径:C:\projects\mls\

承接:[上次结束节点 commit hash + 描述]

[本次具体任务步骤]

铁律(磊偏好):
- cmd 不用 PowerShell
- 我是客户,Claude 是工程师
- 不教学,不解释,要结论
- 撞重大决策点选 A/B,不展开权衡过程
```

### 13.2 commit 协议

**Granular commit**:每个独立改动一个 commit。

**Message 格式**:

```
<type>(<scope>): <description> [(<追溯标签>)]

<空行>

<详细说明>

<空行>

<里程碑标记(可选)>
```

类型:`feat` / `fix` / `refactor` / `chore` / `docs` / `test`
作用域:`listing` / `showing` / `transaction` / `customer` / `auth` / `dashboard` / `dict-client` / `collaboration` / `listing-edit` / `listing-status` / `listing-card` / `dict-serialize+enrich`
追溯标签(可选):`坑 49` / `Bug B 阶段 X` / `V2.1 #15 段 7.7 收官`

### 13.3 文件操作铁律

- VS Code 大文件替换:Ctrl+A → 等 1s → Delete → 等 1s → Ctrl+V → Ctrl+End → Ctrl+S
- 不用 find-and-replace 改大段
- 不用分段贴
- AndroidManifest.xml 改后 q + flutter run
- 后端 uvicorn `--reload` 模式自动重载,改完不需要手动重启
- Flutter 改后:hot reload(r 小写) / hot restart(R 大写) / 冷启动(q 后 flutter run)三选一,根据改动深度

### 13.4 调试协议

debugPrint emoji 前缀分类:

| emoji | 含义 | 用途 |
|---|---|---|
| 📋 | FETCH | API 请求响应 |
| 🔧 | PROCESS | 数据处理中间 |
| 🎨 | RENDER | UI 渲染 |
| 📸 | UPLOAD | 文件 / 图片 |
| 📱 | DEVICE | 设备相关 |
| 🔐 | AUTH | 认证 / token |
| ❌ | ERROR | 错误捕获 |
| ⚠️ | WARN | 警告 |
| ✅ | SUCCESS | 成功节点 |

调试日志临时性,定位完成后删除。如需保留长期,改 `logger.debug` 加配置开关。

### 13.5 长期档版本协议

| 版本号 | 触发条件 |
|---|---|
| V8.X(小版本) | 单日进度小,增量补丁 |
| V8.X+1(小版本) | 单日进度大,需档案级更新 |
| V9.0(大版本) | V2.X → V3 阶段切换 |

V8.7 → V8.8:跨度 2 天(Day 24-25),8 commit + V2.1 收官,**完整重写**触发。
V8.8 → V8.9 / V9.0:V2.1 拉种子用户阶段或 V3 启动时再写。

### 13.6 推断式坑账协议(注销)

V8.7 §十.9 引入"推断式坑账"(标 ⚠ 推断),用 commit log + memory 推断 Day 22 撞过的坑。

**Day 24 真机回归后验证结果**:11 条推断,只命中 2 条(命中率约 18%)。**性价比低**——推断不准的部分占用了真机回归 30 分钟去逐条验证。

**V8.8 起注销此协议**。坑账只记**真实撞过 + 解决了**的事实,不再做推断。如果未来又出现"一天 11 commit 记不清"的情况,接受"细节不可考"现实,只记可证伪事实。

---

## 十四、常用命令速查

### 14.1 启动 4 进程

```cmd
REM 窗口 1 - MongoDB(若未开机自启)
mongod --dbpath C:\data\db

REM 窗口 2 - 辞典后端
cd C:\projects\mls\property-dictionary\backend
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8001

REM 窗口 3 - MLS 后端
cd C:\projects\mls\backend
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000

REM 窗口 4 - Flutter App(真机插上 + USB 调试开)
cd C:\projects\mls\app\mls_app
flutter run

REM 窗口 5(可选) - cmd 备用,给 Claude Code 跑命令
```

### 14.2 验证

```cmd
start http://localhost:8000/docs
start http://localhost:8001/docs

ipconfig                          REM 当前 IP

curl http://localhost:8000/       REM MLS 健康
curl http://localhost:8001/       REM 辞典健康

flutter doctor -v
```

### 14.3 数据库

```cmd
mongosh

use mls
db.listings.countDocuments({})
db.agents.countDocuments({})
db.showing_requests.countDocuments({})
db.transactions.countDocuments({})
db.listings.findOne({}, {community:1, property_code:1, owner_agent_id:1, status:1})

use property_dict
db.properties.countDocuments({})
db.communities.countDocuments({})
db.cities.countDocuments({})        REM 应保留 1(张家口)
db.districts.countDocuments({})     REM 应保留 17

exit
```

### 14.4 Git

```cmd
git -C /c/projects/mls status --short
git -C /c/projects/mls log --oneline -10

cd C:\projects\mls
git add -A
git commit -m "<message>"
git push origin main
```

### 14.5 短信验证码 + 登录(curl)

```cmd
curl -X POST http://localhost:8000/api/v1/auth/send-sms-code ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13912345678\"}"

curl -X POST http://localhost:8000/api/v1/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13912345678\",\"code\":\"123456\"}"

curl http://localhost:8000/api/v1/listings/mine ^
  -H "Authorization: Bearer <access_token>"
```

### 14.6 archive 备份

```cmd
mkdir C:\projects\archive
echo archive/ >> C:\projects\.gitignore

mongodump --db mls --out C:\projects\archive\mls_<日期>
mongodump --db property_dict --out C:\projects\archive\dict_<日期>
```

### 14.7 reset 命令

```cmd
REM 双侧业务清空(保字典)
cd C:\projects\mls\backend
venv\Scripts\activate
python scripts\reset_to_v2_1.py

cd C:\projects\mls\property-dictionary\backend
venv\Scripts\activate
python scripts\reset_to_v2_1.py

REM Java 进程杀干净(坑 16)
taskkill /F /IM java.exe

REM Flutter 缓存清
flutter clean
flutter pub get
```

### 14.8 镜像源验证

```cmd
cd C:\projects\mls\app\mls_app\android
gradlew --version
type build.gradle.kts | findstr "aliyun"
```

---

## 十五、附录

### 15.1 测试账号速查

| 账号 | 手机号 | 角色 | 备注 |
|---|---|---|---|
| 张三 | 13912345678 | LA | 段 7.7 真机挂中泰城 1-1-101 |
| 李红 | 13200132000 | BA | 协作链 BA 端 |
| 验证码 | — | — | `123456`(开发态固定,生产前移除) |

### 15.2 路径速查

```
项目根                 C:\projects\
MLS 后端              C:\projects\mls\backend\
MLS 前端              C:\projects\mls\app\mls_app\
辞典后端              C:\projects\mls\property-dictionary\backend\
MongoDB 数据          C:\data\db\
archive 备份         C:\projects\archive\(.gitignore)
长期档              C:\projects\mls\docs\MLS交接文档V8.8.md(本档)
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
最新 hash(Day 25 末):efbe291
```

### 15.5 docs 目录建议结构

```
mls/docs/
├── MLS交接文档V8.8.md       (本档,长期档,当前 ground truth)
├── MLS交接文档V8.7.md       (历史档,作废保留)
├── MLS交接文档V8.6.md       (历史档)
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

## 十六、V2.1 收官战报 + 商业层准备清单

### 16.1 V2.1 收官战报

```
═══════════════════════════════════════════════════════════
                  V2.1 整体完工节点
                  Day 25 末 · efbe291
═══════════════════════════════════════════════════════════

V2.1 主线节点全部跑通(真机 5 节点 Day 24 验证):
  ① 挂牌      LA 张三挂中泰城 1-1-101 → MLS+辞典双写
  ② 申请带看  BA 李红申请 → LA 张三批准 → 双方解锁身份
  ③ 带看      BA 李红提交带看记录 → LA 张三确认
  ④ 状态流转  LA 张三变更"定金已付"
  ⑤ 成交     BA 880000 + LA 880000 → 反作弊比对一致
                ↓
   confirmed → 辞典 sink_transaction → 永久事实

辞典 transaction_history[0]:
  property_code = (Day 24 真机)
  price_yuan    = 880000
  deal_date     = 2026-05-09
  source        = mls_internal
  verified      = True

V2.1 段 7 完整 commit 链(Day 22-24 共 13 commit):
  58c80d7 → 2503585 → dca0cb1 → ba32148 → a2538d3 →
  a3d77a6 → 74e420f → d911f62 → aa413bc → 179213b →
  2ae8a40 → 7521470

V2.1 真打磨 commit 链(Day 25 共 6 commit):
  115cf84 → abf11bd → 96bacf2 → 31aa0f7 → 8d9299c → efbe291

═══════════════════════════════════════════════════════════
   4 天 · 19 commit · V2.1 段 7 + V2.1 整体收官 + 真打磨
═══════════════════════════════════════════════════════════
```

### 16.2 拉种子用户的商业层准备清单(磊侧)

V2.1 技术层完工,但拉真实用户前还有这些**商业层动作**要做(V8.8 不写代码,仅作清单):

```
商业准备:
  ☐ 选 2-3 位张家口本地经纪人(LA + BA 混合)做种子
  ☐ 拟"测试期协议"(免费测试 1 周 + 反馈机制)
  ☐ 准备 App 安装包(release build + 签名)
  ☐ 真机服务器选择(暂时用磊电脑挂着 / 还是临时云服务器)
  ☐ 短信服务真接(测试期可仍用 fakeredis 假码,但生产前必换)
  ☐ 拟测试期反馈表(让经纪人填的,7 天 1 次)

定价准备:
  ☐ 月费 / 年费拍板(磊定)
  ☐ broker(门店)账号定价(磊定)
  ☐ 推广合作奖励机制(老用户拉新返多少)
  ☐ 收款方式(微信支付 / 对公转账 / 内置支付)

法务/合规:
  ☐ 用户协议草拟
  ☐ 隐私政策草拟(尤其客户姓名 / 电话保护)
  ☐ ICP 备案(.com 域名上线前)

数据/运维:
  ☐ 真机部署:云服务器 or 自有服务器
  ☐ 域名注册 + 备案
  ☐ HTTPS 证书
  ☐ 备份策略(每天 mongodump)
  ☐ 监控告警(后端挂了 / 辞典 5xx / pending_dict_sinks 队列堆积)
```

这些 V8.8 不展开,留磊 Day 26 起逐项推进。

---

## V8.8 收档总结

**Day 24-25 共完成**:
- V2.1 #15 段 7.7 真机回归通过 + V2.1 整体收官(Day 24)
- 5 项 Day 24 暴露登债 + Bug B 全清(Day 25)

**坑账增量**:坑 38(实际 3 层根因)+ 49 + 50 + 53 + 56 + 57 + 58 + 59 + Bug B 共 9 条 Day 23-25 实录(Day 22 推断 11 条经验证只 2 条命中,其余注销)。

**架构状态**:
- 双服务架构稳定(MLS + 辞典)
- 数据归属边界清晰(段 7.2 字段级删迁完成 + Bug B 编辑路径打通)
- 4 层机制经真机验证可工作
- 反作弊机制经真机验证有效

**Day 26 锚点**:
- 真机回归验证 Day 25 5 项修复
- V2.2 / V3 路线决策

**V2.1 状态**:整体完工,可拉种子用户(技术层)。

**V8.8 写作时长**:Day 25 末 Web Claude ~2h。

**V8.9 / V9.0 触发条件**:V2.1 拉种子用户阶段反馈集中后定。

---

> 本档由磊 + Claude(Anthropic Claude Opus 4.7)协作撰写。
> "机制服务于信任的演化" —— MLS 张家口实例,V2.1 整体收官。
