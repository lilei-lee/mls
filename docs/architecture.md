# MLS 架构文档

> 基于代码实际内容撰写，所有路径/字段/枚举值均可在代码中找到对应出处。
> 最后更新：2026-06-10

---

## 1. 后端分层

```
main.py  (~1483 行)         ← 入口 + 全部路由 + JWT/SMS + startup
  ├── config.py              ← 环境变量统一入口（MONGO_URI / SECRET_KEY / MinIO 等）
  ├── database.py            ← MongoDB 连接（全局 client 单例）
  ├── db_router.py           ← 按城市分库 mls_{city}（默认 mls_zhangjiakou）
  ├── storage.py             ← MinIO 客户端（照片上传/读取）
  │
  ├── listings.py            ← 房源 CRUD + 格式器（1255 行）
  ├── showing_requests.py    ← 带客申请
  ├── showings.py            ← 带看记录
  ├── transactions.py        ← 成交双盲填价 + 比对引擎
  ├── settlements.py         ← 奖金结算
  ├── collaborations.py      ← 协作聚合（进度推算）
  ├── communities.py         ← 小区管理
  ├── customers.py           ← 客户管理
  ├── dashboard_v6.py        ← V6 数据大屏 5 卡聚合
  │
  ├── qna.py                 ← Q&A 问答（独立 Router）
  ├── photos.py              ← 照片上传/读取（独立 Router）
  │
  ├── scheduler.py           ← APScheduler 定时任务
  ├── dictionary_client.py   ← 辞典微服务 HTTP 客户端（端口 8001）
  │
  ├── const/sale_points.py   ← 卖点标签预设库
  ├── services/              ← 业务服务层
  │   ├── listing_enrich.py  ← 辞典 enrich（物理字段 + 小区信息）
  │   └── listing_filter.py  ← 共享库后端筛选
  └── utils/
      ├── anonymize.py       ← 姓名脱敏（姓氏 + *）
      └── collaboration_status.py ← 协作可见性判定
```

### 各模块职责

| 文件 | 职责 | 行数 | 备注 |
|---|---|---|---|
| `main.py` | 入口 + 路由 + JWT + SMS + 索引初始化 | 1483 | 待拆分为路由模块 |
| `listings.py` | 房源模型、CRUD、格式化、辞典对接 | 1255 | 业务最重的模块 |
| `config.py` | 环境变量统一读取 | 43 | 全部有合理默认值 |
| `database.py` | MongoDB 连接管理 | 33 | 全局 client + collection 暴露 |
| `db_router.py` | 城市→DB 路由 | 25 | 默认 `mls_zhangjiakou` |
| `storage.py` | MinIO 对象存储 | 92 | 上传/读取/bucket 自检 |
| `transactions.py` | 成交双盲填价 + `_compare_and_finalize` 比对引擎 | ~400 | 反作弊基石 |
| `collaborations.py` | 协作进度聚合 | ~250 | `_compute_stage()` 六阶段推算 |

---

## 2. 核心业务流

### 2.1 注册 / 登录

```
POST /api/v1/auth/send-sms-code    → fakeredis 存 code (TTL 300s)
POST /api/v1/auth/register          → agents.insert_one + 返回 access+refresh token
POST /api/v1/auth/login             → 验 code → 查 agents → 签发双 token
POST /api/v1/auth/refresh           → 验 refresh → 黑名单旧 refresh → 签发新双 token
POST /api/v1/auth/logout            → refresh 入黑名单
```

Mongo 集合：`agents`（手机号唯一索引）

### 2.2 挂牌（LA 发布房源）

```
POST /api/v1/listings
  1. 生成 house_code (MD5: community#building#unit#room_no)
  2. 查重 (house_code 唯一)
  3. 调辞典 identify + submit_claim (物理字段 claim 到 property-dictionary:8001)
  4. listings.insert_one (营销字段 + property_code)
  5. 返回 listing_id
```

Mongo 集合：`listings`（索引: `house_code`, `owner_agent_id`, `status`, `community_id`）

辞典同步链路：
```
POST /api/v1/listings          → create_listing() → DictionaryClient.identify() → claim()
POST /api/v1/listings/{id}/sync-physical  → 单独触发物理字段同步
```

### 2.3 带看申请 → LA 审批 → 带看记录 → LA 确认

```
POST   /api/v1/showing-requests           ← BA 发起申请
  → showing_requests_collection.insert_one(status='pending')

POST   /api/v1/showing-requests/{id}/approve  ← LA 审批通过
  → status='approved'

POST   /api/v1/showings                    ← BA 提交带看（照片 + 时间）
  → showings_collection.insert_one(status='pending_confirm')

POST   /api/v1/showings/{id}/confirm       ← LA 确认带看
  → status='confirmed'（乐观锁: status='pending_confirm'）

POST   /api/v1/showings/{id}/reject        ← LA 驳回（必须填理由）
  → status='rejected'
```

Mongo 集合：`showing_requests`, `showings`

### 2.4 直接带看 1:N（BA 已有客户，直接从客户档案发起）

```
POST /api/v1/customers/{id}/direct-showing
  → 先调用 can_direct_showing() 判定（listing 在可带看态）
  → 跳过 showing_request，直接创建 showing (status='pending_confirm')
  → 不经过申请/审批流程
```

入口：`customers.py:create_direct_showing()`

### 2.5 成交双盲填价比对（反作弊基石）

```
POST /api/v1/transactions/initiate                    ← BA 发起
  → transactions_collection.insert_one(status='pending_la_confirm')
  → 前置: showing.status='confirmed' + listing.status in (deposit_paid, transaction_ongoing)

POST /api/v1/transactions/{id}/la-confirm             ← LA 独立填价
  → _compare_and_finalize() 比对引擎:
     - 价格一致 + 日期一致 → confirmed (房源→sold, 自动触发 settlement)
     - 任一不一致 → rejected (三分支 reject_reason)

POST /api/v1/transactions/{id}/la-reject              ← LA 手动驳回
POST /api/v1/transactions/{id}/cancel                 ← BA 撤回
POST /api/v1/transactions/{id}/update-my              ← BA 改自己填报(rejected 态下)
POST /api/v1/transactions/{id}/update-my-la           ← LA 改自己填报(rejected 态下)
```

**视角脱敏规则**（`_format_listing_full` + `transactions._format`）：
- `pending_la_confirm` 态下 LA 看不到 BA 填的价/日期/备注
- `confirmed` 后双方互见
- 非协作伙伴看不到 `agent_remarks` / `showing_instructions` / 房号

Mongo 集合：`transactions`, `settlements`

### 2.6 奖金结算

```
POST /api/v1/settlements/{id}/la-mark-paid          ← LA 标记已付款
  → status: pending_payment → pending_receipt
  → BA 确认收款（待 B 做完后开放）

POST /api/v1/settlements/{id}/ba-confirm-receipt    ← BA 确认（即将开放）
```

结算单在 `transaction.confirmed` 时由 `sink_transaction_to_dict()` 自动创建。
Mongo 集合：`settlements`

### 2.7 照片上传 / 读取

```
POST /api/v1/photos          → 鉴权 → 校验类型(JPEG/PNG) → 校验 ≤5MB → storage.upload_photo → 返回 key+url
GET  /api/v1/photos/{key}    → 鉴权 → storage.get_photo → StreamingResponse (Cache-Control: private, max-age=86400)
```

**双轨判定规则**（`listings.py:_derive_cover_thumbnail`）：
- `photo_key` 优先：新照片走 MinIO，API 路径形如 `/api/v1/photos/{key}`
- `data` 兜底：旧 base64 照片原样透传，不迁移
- `cover_thumbnail` 回退：首图有 `photo_key` → 自动推导 `/api/v1/photos/{pk}`；否则维持 base64

---

## 3. MongoDB 集合清单

| 集合名 | 用途 | 关键字段 | 状态枚举 |
|---|---|---|---|
| `agents` | 经纪人 | `_id`, `phone`(唯一), `name`, `status`(active/deleted/banned), `role` | — |
| `listings` | 房源 | `_id`, `house_code`(唯一), `owner_agent_id`, `status`, `price_wan`, `photos[]`, `cover_thumbnail`, `community_id` | `on_sale`, `deposit_paid`, `transaction_ongoing`, `sold`, `offline` |
| `showing_requests` | 带客申请 | `_id`, `listing_id`, `buyer_agent_id`, `listing_agent_id`, `status`, `customer_id` | `pending`, `approved`, `auto_approved`, `rejected`, `expired`, `cancelled`, `merged_into_prior` |
| `showings` | 带看记录 | `_id`, `showing_request_id`, `listing_id`, `ba_agent_id`, `la_agent_id`, `status`, `photos[]`, `showing_time` | `pending_confirm`, `confirmed`, `rejected` |
| `transactions` | 成交记录 | `_id`, `showing_id`, `listing_id`, `ba_agent_id`, `la_agent_id`, `status`, `ba_deal_price_yuan`, `la_deal_price_yuan` | `pending_la_confirm`, `confirmed`, `rejected`, `cancelled` |
| `settlements` | 奖金结算 | `_id`, `transaction_id`, `listing_id`, `la_agent_id`, `ba_agent_id`, `status`, `bonus_yuan` | `pending_payment`, `pending_receipt`, `settled`, `disputed` |
| `customers` | 客户 | `_id`, `owner_agent_id`, `surname`, `phone`, `gender`, `requirements`, `status` | `active`, `closed` |
| `communities` | 小区 | `_id`, `name`, `district`, `stats` | — |

---

## 4. 前后端状态值对照

> 只记录不一致或单边缺失的。**一致项不列**（如 `on_sale` → "在售" 两侧相同）。
> 此清单为下一步 constants 统一的输入，本次只记录不修改。

### 4.1 后端有、前端 StatusLabels 缺失

| 值 | 后端定义 | 说明 |
|---|---|---|
| `merged_into_prior` | `showing_requests.py`: 1:N 路径合并 | `status_labels.dart` `_showingRequest` 未收录 |
| （已补齐）| | |

### 4.2 前端 AppStatusBadge 有、后端 StatusLabels 无对应

| 值 | 前端定义 | 说明 |
|---|---|---|
| `paused` | `app_status_badge.dart:10` listing 颜色表 | 后端 `ALL_STATUSES` 无此值 |
| `showing_done` | `app_status_badge.dart:18` collab 颜色表 | 后端无此状态（协作阶段推算用 `_compute_stage` 而非单 status）|
| `transaction_initiated` | `app_status_badge.dart:19` | 后端用 `pending_la_confirm`，前端协作卡片另算 |
| `canceled` (单 l) | `app_status_badge.dart:21` | 后端用 `cancelled` (双 l) |

### 4.3 同一概念两侧 key 不同

| 概念 | 后端 key | 前端 key | 位置 |
|---|---|---|---|
| 待 LA 确认（带看）| `pending_confirm` | `pending_confirm` | ✅ 一致（Day 16 修订后）|
| 待 LA 填价（成交）| `pending_la_confirm` | `pending_la_confirm` | ✅ 一致 |

---

## 5. 鉴权机制

### 服务端（`main.py`）

```
get_current_agent (Depends)
  → Extracts Bearer token
  → jwt.decode(token, SECRET_KEY, HS256)
  → 验 type == "access"
  → agents_collection.find_one({_id: sub})
  → 检查 deleted / banned
  → 返回 agent dict
```

Token 生命周期：
- access: 2h（`ACCESS_TOKEN_EXPIRE_HOURS`）
- refresh: 30d（`REFRESH_TOKEN_EXPIRE_DAYS`）
- refresh 使用后立即入黑名单（SHA-256 hash → fakeredis, TTL = 剩余有效期）

### 客户端（`api_client.dart`）

401 刷新队列流程：
```
请求 → 401?
  ├─ 非 401 → 正常返回
  └─ 401
      ├─ 正在 refresh (_isRefreshing=true) → 入队等待 (_pendingQueue)
      └─ 发起 refresh
          ├─ 成功 → 存新 token → 重放当前请求 → 逐个重放队列
          └─ 失败 → 清空 storage → 跳转 /login → 拒绝队列中所有请求
```
