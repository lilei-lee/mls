# MLS — 张家口二手房经纪人协作系统

B 端 SaaS。**不抽佣，靠会员费**。模仿美国 MLS 机制：
LA 挂房 → 共享库 → BA 带客 → 双方独立留痕合作 → 成交盲填价比对 → 奖金结算。

核心理念：**机制服务于信任的演化**。反作弊基石是「双方独立填价比对」，任何自动放宽差异阈值的需求都必须先拒绝再讨论。

---

## 技术栈

| 层 | 技术 | 备注 |
|---|---|---|
| 前端 | Flutter 3.41.7 / Dart 3.11.5 | go_router + dio + JetBrains Mono |
| 后端 | FastAPI 0.136 / Python 3.11 | uvicorn 启动，1483 行单文件路由 |
| 数据库 | MongoDB 8.2 / pymongo 4.16 | 无 ORM，直拼 dict；按城市分库 `mls_{city}` |
| 对象存储 | MinIO（minio-py 7.2.10）| 照片新上传走 MinIO，旧 base64 兼容 |
| 鉴权 | JWT HS256 | access 2h + refresh 30d + Token Rotation + 黑名单 |
| 缓存 | fakeredis 2.35.1 | 开发期内存 Redis，验证码 + refresh 黑名单 |
| 调度 | APScheduler 3.11.2 | 夜间清理过期数据 |
| 辞典 | 独立 FastAPI 微服务（端口 8001）| 物理字段/小区数据外部化 |

---

## 目录结构

```
mls/                              # 仓库根
├── README.md                     # 本文档 — 接手指南
├── CLAUDE.md                     # Claude Code 工作手册（核心，含铁律/坑库）
├── Dockerfile                    # 后端容器镜像
├── .dockerignore
│
├── backend/                      # ── Python 后端 ──
│   ├── main.py                   # 入口 + 全部路由（1483 行，待拆分）
│   ├── config.py                 # 统一配置中心（环境变量）
│   ├── database.py               # MongoDB 连接（全局 client 单例）
│   ├── db_router.py              # 按城市分库路由 mls_{city}
│   ├── listings.py               # 房源 CRUD + 格式器（1255 行）
│   ├── showing_requests.py       # 带客申请
│   ├── showings.py               # 带看记录
│   ├── transactions.py           # 成交双盲填价
│   ├── settlements.py            # 奖金结算
│   ├── collaborations.py         # 协作记录
│   ├── communities.py            # 小区管理
│   ├── customers.py              # 客户管理
│   ├── dashboard_v6.py           # V6 数据大屏聚合
│   ├── qna.py                    # Q&A 问答（FastAPI Router）
│   ├── photos.py                 # 照片上传/读取（FastAPI Router）
│   ├── storage.py                # MinIO 对象存储客户端
│   ├── scheduler.py              # 定时任务
│   ├── dictionary_client.py      # 辞典微服务 HTTP 客户端
│   ├── const/sale_points.py      # 卖点标签预设库
│   ├── services/                 # 业务服务
│   │   ├── listing_enrich.py     # 从辞典 enrich 房源
│   │   └── listing_filter.py     # 共享库后端过滤
│   ├── utils/                    # 工具
│   │   ├── anonymize.py          # 姓名脱敏
│   │   └── collaboration_status.py  # 协作可见性判定
│   ├── scripts/                  # 一次性迁移/播种脚本
│   ├── tests/                    # pytest（16 个测试文件）
│   ├── requirements.txt
│   └── .env                      # 环境变量（gitignore）
│
├── app/mls_app/                  # ── Flutter 前端 ──
│   ├── lib/
│   │   ├── main.dart             # 入口
│   │   ├── config/api_config.dart  # API 地址（支持 dart-define）
│   │   ├── router/app_router.dart  # go_router 路由表
│   │   ├── theme/                # MlsColors / MlsTypography / MlsRadius / MlsShadows
│   │   ├── models/               # 数据模型（ListingFilters 等）
│   │   ├── services/             # API 调用层（每个文件对应后端一组路由）
│   │   ├── screens/              # 页面（home/listings/customers/chat/trace/...)
│   │   ├── widgets/              # 可复用组件
│   │   │   ├── mls/              # MLS 设计系统组件库（MlsCard/MlsAvatar/...)
│   │   │   ├── base64_image.dart # 图片渲染
│   │   │   └── filter_sheet.dart # 筛选面板
│   │   ├── components/           # 通用组件（AppStatusBadge/AppEmpty 等）
│   │   └── utils/                # 工具函数（time_format/price_validation）
│   ├── test/                     # Flutter 单元测试
│   └── pubspec.yaml
│
├── property-dictionary/          # ── 辞典微服务（独立 FastAPI，端口 8001）──
├── docs/                         # 业务设计文档 + 架构文档
├── handoff/                      # 开发交接档
└── _incoming/                    # 设计稿收件箱
```

---

## 本地启动

### 1. 后端

```powershell
# 进入后端目录
cd C:\projects\mls\backend

# 激活虚拟环境
.\venv\Scripts\activate

# 安装依赖（首次）
pip install -r requirements.txt

# 设置环境变量（PowerShell）
$env:MONGO_URI = "mongodb://localhost:27017"
$env:MINIO_ENDPOINT = "192.168.0.200:9000"
$env:MINIO_ACCESS_KEY = "minioadmin"
$env:MINIO_SECRET_KEY = "minioadmin"
$env:MINIO_BUCKET = "mls-photos"

# 启动
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. 前端

```powershell
cd C:\projects\mls\app\mls_app

# 获取依赖
flutter pub get

# 启动（指定后端地址）
flutter run --dart-define=API_BASE_URL=http://192.168.0.105:8000

# 模拟器用 10.0.2.2 替代电脑 IP
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

> ⚠️ 每次电脑换 WiFi 或路由器重启后 IP 会变。如果手机连不上，先 `ipconfig` 查当前 IP，
> 然后用 `--dart-define` 覆盖 `api_config.dart` 中的默认值。

### 3. 辞典服务

```powershell
cd C:\projects\property-dictionary\backend
.\venv\Scripts\activate
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

---

## 环境变量总表

| 变量名 | 用途 | 默认值 | 必填 |
|---|---|---|---|
| `MONGO_URI` | MongoDB 连接串 | `mongodb://localhost:27017` | 否 |
| `SECRET_KEY` | JWT 签名密钥 | 见 `config.py` 中的硬编码值 | **生产必填** |
| `MINIO_ENDPOINT` | MinIO 服务地址 | `localhost:9000` | 否 |
| `MINIO_ACCESS_KEY` | MinIO 访问密钥 | `""`（空字符串）| 生产时填 |
| `MINIO_SECRET_KEY` | MinIO 密钥 | `""`（空字符串）| 生产时填 |
| `MINIO_BUCKET` | 照片 bucket 名称 | `mls-photos` | 否 |
| `MINIO_SECURE` | MinIO 是否 HTTPS | `false` | 否 |
| `DEV_SMS_CODE` | 开发期固定验证码 | `123456` | 否 |
| `DEFAULT_MLS_CITY` | 默认城市（DB 路由）| `zhangjiakou` | 否 |
| `DICT_BASE_URL` | 辞典服务地址 | `http://localhost:8001/v1` | 否 |
| `DICT_API_KEY` | 辞典服务 API Key | 见 `.env` | 否 |

---

## NAS 部署拓扑（192.168.0.200）

```
┌─────────────────────────────────────────────────────┐
│  NAS 192.168.0.200                                   │
│                                                      │
│  ┌──────────────────┐  ┌──────────────────┐         │
│  │ MinIO :9000 (API) │  │ MongoDB :27017    │         │
│  │      :9001 (WebUI) │  │ mls_zhangjiakou   │         │
│  │ bucket: mls-photos │  └──────────────────┘         │
│  │ (private)          │                               │
│  └──────────────────┘  ┌──────────────────┐         │
│                         │ 后端 :8000        │         │
│                         │ (compose 中当前   │         │
│                         │  注释待启用)      │         │
│                         └──────────────────┘         │
└─────────────────────────────────────────────────────┘
```

MinIO bucket `mls-photos` 设为 **private**（不公开），所有照片读取走后端鉴权接口。
Docker Compose 中 backend 块当前处于注释状态，待 NAS 环境验证后启用。

---

## 团队规约

> 以下为团队约定，新成员务必遵守。部分条目是目标状态（标注「即将」），
> 后续重构会逐步落实。

1. **读 Mongo 文档一律 `.get()` 带默认值**，禁止 `doc["field"]` 直接索引（KeyError 风险）。
   写入一律过 Pydantic 模型验证。
2. **状态值禁止裸字符串**。前后端所有 status 值统一走 constants 模块（即将建立）。
   当前分散在 `listings.py:STATUS_LABELS`、`status_labels.dart`、`app_status_badge.dart` 中，
   下一步合并为单一真相源。
3. **验证码 `123456` 仅开发用**。生产环境通过 `DEV_SMS_CODE` 覆盖，终极方案接入真实短信。
4. **`SECRET_KEY` 已进 git 历史**。NAS 部署时必须通过环境变量换新随机值：
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```
5. **照片双轨共存，不回迁**：
   - 旧数据：`PhotoItem.data`（base64 字符串，直接存在 MongoDB）
   - 新数据：`PhotoItem.photo_key`（MinIO object key，形如 `photos/2026/06/uuid.jpg`）
   - 读取时 `photo_key` 优先，`data` 兜底。旧 base64 文档保持原样可读，不做批量迁移。
6. **路由注册铁律**：FastAPI 具体路径必须先于动态 `{param}` 路径注册（`main.py` 已遵守）。
7. **写库脚本必须先 dry-run**，输出影响行数，等确认后再 apply。

---

## 测试账号

| 身份 | 手机号 | 角色 |
|---|---|---|
| 张三 | 13912345678 | LA（挂牌经纪人）|
| 李红 | 13200132000 | BA（带客经纪人）|

开发期验证码固定为 `DEV_SMS_CODE` 环境变量值（默认 `123456`）。

---

## 文档导航

- **`CLAUDE.md`** — Claude Code 工作手册（**核心**，含技术栈、铁律、坑库、协作约定）
- **`docs/architecture.md`** — 架构文档（业务流、集合清单、前后端状态对照）
- **`docs/runbook.md`** — 故障定位手册（症状→诊断→修复）
- `docs/` — 业务设计文档（V10 决策汇总）
- `handoff/` — 开发交接档

---

## 项目作者

磊（创始人 + 唯一开发者）+ Claude（AI 协作伙伴）

> *9 个月，从 0 到 V2 94%，31 个坑，80+ 个产品决策，3 次大重构，1 次跨电脑迁移。*
