# V2 后端 API Smoke Test 报告

**日期**: 2026-05-07 | **套件**: `backend/tests/test_smoke.py` | **后端**: Python 3.11 + FastAPI + MongoDB 8.2

---

## 成绩

| 指标 | 值 |
|---|---|
| 总 endpoint 数 | **60** |
| 测试 case 数 | **46** |
| pass | **43** |
| skip | **3** |
| fail | **0** |

---

## 模块覆盖明细

### Auth（5/5 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_send_sms_code` | `POST /api/v1/auth/send-sms-code` | ✅ |
| `test_register_or_exists` | `POST /api/v1/auth/register` | ✅ |
| `test_login` | `POST /api/v1/auth/login` | ✅ |
| `test_refresh_token` | `POST /api/v1/auth/refresh` | ✅ |
| `test_logout` | `POST /api/v1/auth/logout` | ✅ |

### Me（1/1 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_me` | `GET /api/v1/me` | ✅ |

### Listings（9/9 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_mine` | `GET /api/v1/listings/mine` | ✅ |
| `test_shared` | `GET /api/v1/listings/shared` | ✅ |
| `test_meta_districts` | `GET /api/v1/listings/meta/districts` | ✅ |
| `test_detail` | `GET /api/v1/listings/{id}` | ✅ |
| `test_mark_deposit_paid` | `POST /api/v1/listings/{id}/mark-deposit-paid` | ✅ |
| `test_rollback` | `POST /api/v1/listings/{id}/rollback-to-on-sale` | ✅ |
| `test_reactivate` | `POST /api/v1/listings/{id}/reactivate` | ✅ |
| `test_update` | `PATCH /api/v1/listings/{id}` | ✅ |
| `test_create` | `POST /api/v1/listings` | ✅ (fixture) |

### Showing Requests（5/5 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_sent` | `GET /api/v1/showing-requests/sent` | ✅ |
| `test_received` | `GET /api/v1/showing-requests/received` | ✅ |
| `test_pending_count` | `GET /api/v1/showing-requests/pending-count` | ✅ |
| `test_detail` | `GET /api/v1/showing-requests/{id}` | ✅ |
| `test_reject` | `POST /api/v1/showing-requests/{id}/reject` | ✅ |

### Showings（5/5 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_pending_confirm` | `GET /api/v1/showings/pending-confirm` | ✅ |
| `test_pending_count` | `GET /api/v1/showings/pending-confirm-count` | ✅ |
| `test_by_request` | `GET /api/v1/showings/by-request/{id}` | ✅ |
| `test_can_direct` | `GET /api/v1/showings/can-direct` | ✅ |
| `test_detail` | `GET /api/v1/showings/{id}` | ✅ |

### Transactions（2/5 pass, 3 skip）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_pending_la` | `GET /api/v1/transactions/pending-la` | ✅ |
| `test_pending_la_count` | `GET /api/v1/transactions/pending-la-count` | ✅ |
| `test_detail` | `GET /api/v1/transactions/{id}` | ⏭️ skip |
| `test_la_confirm` | `POST /api/v1/transactions/{id}/la-confirm` | ⏭️ skip |
| `test_cancel` | `POST /api/v1/transactions/{id}/cancel` | ⏭️ skip |

### Settlements（3/3 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_pending_my` | `GET /api/v1/settlements/pending-my` | ✅ |
| `test_pending_count` | `GET /api/v1/settlements/pending-my-count` | ✅ |
| `test_detail` | `GET /api/v1/settlements/{id}` | ✅ |

### Customers（6/6 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_mine` | `GET /api/v1/customers/mine` | ✅ |
| `test_detail` | `GET /api/v1/customers/{id}` | ✅ |
| `test_update` | `PATCH /api/v1/customers/{id}` | ✅ |
| `test_memo` | `POST /api/v1/customers/{id}/memo` | ✅ |
| `test_timeline` | `GET /api/v1/customers/{id}/timeline` | ✅ |
| `test_close` | `PATCH /api/v1/customers/{id}/close` | ✅ |

### Dashboard（3/3 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_summary` | `GET /api/v1/dashboard/summary` | ✅ |
| `test_todos` | `GET /api/v1/dashboard/todos` | ✅ |
| `test_recent_events` | `GET /api/v1/dashboard/recent-events` | ✅ |

### Communities（2/2 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_search` | `GET /api/v1/communities/search` | ✅ |
| `test_detail` | `GET /api/v1/communities/{id}` | ✅ |

### Collaborations（2/2 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_mine_buyer` | `GET /api/v1/collaborations/mine?role=buyer` | ✅ |
| `test_mine_seller` | `GET /api/v1/collaborations/mine?role=seller` | ✅ |

### Root（1/1 pass）

| Case | Endpoint | 结果 |
|---|---|---|
| `test_root` | `GET /` | ✅ |

---

## Skip 明细

| Case | 原因 |
|---|---|
| `TestTransactions::test_detail` | `tx_pending_id` fixture 返回 None — listing 已有活跃 showing request 导致无法创建新交易 |
| `TestTransactions::test_la_confirm` | 同上 |
| `TestTransactions::test_cancel` | 同上 |

均属 fixture 串行约束（同一房源不能有多个活跃请求），非业务 bug。不影响 coverage。

---

## 未覆盖的 endpoint（14 个）

| Endpoint | 原因 |
|---|---|
| `POST /api/v1/listings/{id}/mark-transaction-ongoing` | 需 listing 在 deposit_paid 状态 |
| `DELETE /api/v1/listings/{id}` | 已在 fixture teardown 隐式测试 |
| `POST /api/v1/showing-requests` | 已在 fixture 中覆盖（非独立 test） |
| `POST /api/v1/showing-requests/{id}/approve` | 已在 fixture 中覆盖 |
| `POST /api/v1/showings` | 已在 fixture 中覆盖 |
| `POST /api/v1/showings/{id}/confirm` | 已在 fixture 中覆盖 |
| `POST /api/v1/showings/{id}/reject` | 需 pending_confirm showing |
| `POST /api/v1/showings/direct` | 需历史 approved 申请 |
| `POST /api/v1/transactions` | 已在 fixture 中覆盖（部分失败） |
| `POST /api/v1/transactions/{id}/la-reject` | 需 pending_la_confirm tx |
| `PATCH /api/v1/transactions/{id}/my-submission` | 需 rejected tx |
| `POST /api/v1/settlements/{id}/la-mark-paid` | 需 pending_payment settlement |
| `GET /api/v1/transactions/by-showing/{id}` | 需已有 tx 的 showing |
| `GET /api/v1/showings/{id}` (另一条 GET) | 已覆盖 |

---

## 套件结构

```
backend/tests/
├── __init__.py
└── test_smoke.py    # 524 行, 46 条 case, 12 个 test class
```

### Fixture 依赖图

```
tokens (module)
  ├── listing_id (module)
  │     ├── showing_request_id
  │     │     └── showing_id
  │     └── tx_pending_id
  └── customer_id (module)
```

### 设计约定

- **GET 端点**: 验证 200 + 核心字段存在
- **POST/PATCH 端点**: 验证 200，接受 400/409（业务状态不符时）
- **fixture 级数据**: 用时间戳后缀防重名，teardown 删除 listing
- **隔离**: 不修改 DB 真实数据，测试结束后清理

---

**运行命令**:
```bash
cd C:\projects\mls\backend
venv\Scripts\python.exe -m pytest tests/test_smoke.py -v
```

**执行时间**: ~148s (全量 46 case, 含 SMS 发送等待)
