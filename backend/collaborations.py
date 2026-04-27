"""
MLS 模块:协作聚合(Day 13 新建)

职责:
- 把 showing_request + showings + transactions + settlements 4 个集合
  串成"协作"对象返给前端,用于进度条展示
- 区分买方协作(BA 视角)和卖方协作(LA 视角)

设计原则:聚合查询,前端不再分别查 4 个接口拼数据
"""

from datetime import datetime
from bson import ObjectId

from database import db


# ============= 阶段计算 =============

# 进度条阶段定义(共 6 步)
STAGE_REQUEST = 0       # 申请
STAGE_APPROVED = 1      # 已通过(申请通过,带看未提交)
STAGE_SHOWING = 2       # 带看
STAGE_TRANSACTION = 3   # 成交
STAGE_PAYMENT = 4       # 付款
STAGE_COMPLETED = 5     # 完成

STAGE_LABELS = ["申请", "已通过", "带看", "成交", "付款", "完成"]


def _compute_stage(request_doc, showing_doc, transaction_doc, settlement_doc):
    """根据 4 个对象的状态推算当前在第几个阶段。
    
    返 (stage_index, stage_status, is_failed)
    - stage_index: 0~5
    - stage_status: 'in_progress' | 'done' | 'failed' | 'expired'
    - is_failed: True 表示协作进入异常终止态
    """
    # 异常态优先
    req_status = request_doc.get("status")
    if req_status == "rejected":
        return (STAGE_REQUEST, "failed", True)
    if req_status == "expired":
        return (STAGE_REQUEST, "expired", True)

    # 申请还在 pending
    if req_status == "pending":
        return (STAGE_REQUEST, "in_progress", False)

    # 申请已通过(approved 或 auto_approved)
    if not showing_doc:
        return (STAGE_APPROVED, "in_progress", False)

    # 有了带看
    showing_status = showing_doc.get("status")
    if showing_status == "rejected":
        return (STAGE_SHOWING, "failed", True)
    if showing_status == "pending_confirm":
        return (STAGE_SHOWING, "in_progress", False)

    # 带看已确认
    if not transaction_doc:
        return (STAGE_SHOWING, "done", False)

    # 有了成交
    tx_status = transaction_doc.get("status")
    if tx_status in ("rejected", "cancelled"):
        return (STAGE_TRANSACTION, "failed", True)
    if tx_status == "pending_la_confirm":
        return (STAGE_TRANSACTION, "in_progress", False)

    # 成交已 confirmed
    if not settlement_doc:
        # confirmed 但没产生 settlement(说明 bonus_yuan = 0)
        return (STAGE_COMPLETED, "done", False)

    # 有了 settlement
    stl_status = settlement_doc.get("status")
    if stl_status == "settled":
        return (STAGE_COMPLETED, "done", False)
    if stl_status in ("pending_payment", "pending_receipt"):
        return (STAGE_PAYMENT, "in_progress", False)
    if stl_status == "disputed":
        return (STAGE_PAYMENT, "failed", True)

    # 兜底
    return (STAGE_PAYMENT, "in_progress", False)


def _stage_status_label(stage, status, is_failed):
    """生成给前端的状态标签文字"""
    if is_failed:
        if status == "failed":
            return "失败"
        if status == "expired":
            return "已过期"
        return "已终止"
    if status == "in_progress":
        return f"{STAGE_LABELS[stage]}中"
    if status == "done" and stage == STAGE_COMPLETED:
        return "已完成"
    return STAGE_LABELS[stage]


# ============= 主聚合函数 =============

def list_my_collaborations(current_agent_id: str, role: str) -> list[dict]:
    """查我的协作列表
    
    role: 'buyer' | 'seller'
    - buyer: 我作为 BA(我带客户)
    - seller: 我作为 LA(别人带客户来我房)
    """
    agent_oid = ObjectId(current_agent_id)

    # 查 showing_requests(协作起点)
    if role == "buyer":
        query = {"buyer_agent_id": agent_oid}
    elif role == "seller":
        query = {"listing_agent_id": agent_oid}
    else:
        return []

    requests = list(
        db["showing_requests"].find(query).sort("created_at", -1).limit(50)
    )

    if not requests:
        return []

    # 批量查关联的 showings
    request_ids = [r["_id"] for r in requests]
    showings_by_req = {}
    for s in db["showings"].find({"showing_request_id": {"$in": request_ids}}):
        showings_by_req[s["showing_request_id"]] = s

    # 批量查关联的 transactions
    showing_ids = [s["_id"] for s in showings_by_req.values()]
    transactions_by_showing = {}
    if showing_ids:
        for t in db["transactions"].find({"showing_id": {"$in": showing_ids}}):
            transactions_by_showing[t["showing_id"]] = t

    # 批量查关联的 settlements
    transaction_ids = [t["_id"] for t in transactions_by_showing.values()]
    settlements_by_tx = {}
    if transaction_ids:
        for stl in db["settlements"].find({"transaction_id": {"$in": transaction_ids}}):
            settlements_by_tx[stl["transaction_id"]] = stl

    # 组装结果
    result = []
    for req in requests:
        showing = showings_by_req.get(req["_id"])
        transaction = (
            transactions_by_showing.get(showing["_id"]) if showing else None
        )
        settlement = (
            settlements_by_tx.get(transaction["_id"]) if transaction else None
        )

        stage, status, is_failed = _compute_stage(
            req, showing, transaction, settlement
        )

        # 找最近动作时间(用于排序和"最近动作"显示)
        last_time = req.get("updated_at") or req.get("created_at")
        last_action_text = "申请已发出"

        if showing:
            if showing.get("updated_at") and showing["updated_at"] > last_time:
                last_time = showing["updated_at"]
            if showing.get("status") == "confirmed":
                last_action_text = "带看已确认"
            elif showing.get("status") == "pending_confirm":
                last_action_text = "带看待 LA 确认"
            elif showing.get("status") == "rejected":
                last_action_text = "带看被驳回"

        if transaction:
            if (transaction.get("updated_at") and
                    transaction["updated_at"] > last_time):
                last_time = transaction["updated_at"]
            if transaction.get("status") == "pending_la_confirm":
                last_action_text = "成交待 LA 填价"
            elif transaction.get("status") == "confirmed":
                last_action_text = "成交已生效"
            elif transaction.get("status") == "rejected":
                last_action_text = "成交被驳回"

        if settlement:
            if (settlement.get("updated_at") and
                    settlement["updated_at"] > last_time):
                last_time = settlement["updated_at"]
            if settlement.get("status") == "pending_payment":
                last_action_text = "等 LA 付款"
            elif settlement.get("status") == "pending_receipt":
                last_action_text = "等 BA 确认收款"
            elif settlement.get("status") == "settled":
                last_action_text = "结算完成"

        # 失败/过期态覆盖文案
        if is_failed:
            if req.get("status") == "rejected":
                last_action_text = f"申请被拒({req.get('reject_reason') or '未填理由'})"
            elif req.get("status") == "expired":
                last_action_text = "申请已过期"

        snapshot = req.get("listing_snapshot", {})
        counterparty_name = (
            req.get("listing_agent_name") if role == "buyer"
            else req.get("buyer_agent_name")
        )

        result.append({
            "collaboration_id": str(req["_id"]),
            "role": role,
            "stage": stage,
            "stage_total": 6,
            "stage_status": status,
            "stage_label": _stage_status_label(stage, status, is_failed),
            "is_failed": is_failed,
            "listing_snapshot": {
                "community": snapshot.get("community", ""),
                "building": snapshot.get("building", ""),
                "unit": snapshot.get("unit", ""),
                "room_no": snapshot.get("room_no", ""),
                "price_wan": snapshot.get("price_wan", 0),
            },
            "counterparty_name": counterparty_name or "",
            "customer_surname": req.get("customer_surname", ""),
            "customer_gender": req.get("customer_gender", ""),
            "last_action_text": last_action_text,
            "last_action_time": last_time.isoformat() if last_time else None,
            # 跳转用的子对象 ID
            "request_id": str(req["_id"]),
            "showing_id": str(showing["_id"]) if showing else None,
            "transaction_id": str(transaction["_id"]) if transaction else None,
            "settlement_id": str(settlement["_id"]) if settlement else None,
        })

    # 按 last_action_time 降序(已经按 created_at 取的,大致符合)
    result.sort(
        key=lambda x: x.get("last_action_time") or "",
        reverse=True,
    )
    return result