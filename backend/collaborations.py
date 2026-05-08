"""
MLS 模块:协作聚合(Day 13 新建,Day 15 重构支持 1:N 带看)

职责:
- 把 showing_request + showings + transactions + settlements 4 个集合
  串成"协作"对象返给前端,用于进度条展示
- 区分买方协作(BA 视角)和卖方协作(LA 视角)
- 1 申请 → N 带看:同一申请下挂多条带看记录,进度条以"最新带看"判定阶段

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


def _compute_stage(request_doc, showings, transaction_doc, settlement_doc):
    """根据状态推算当前在第几个阶段。

    showings: list[dict],按 created_at 倒序(最新在前);可能为空 list

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

    # 申请已通过(approved 或 auto_approved),但还没带看
    if not showings:
        return (STAGE_APPROVED, "in_progress", False)

    # 有 transaction(挂在某一条 showing 上)优先走 transaction/settlement 分支
    if transaction_doc:
        tx_status = transaction_doc.get("status")
        if tx_status in ("rejected", "cancelled"):
            return (STAGE_TRANSACTION, "failed", True)
        if tx_status == "pending_la_confirm":
            return (STAGE_TRANSACTION, "in_progress", False)

        # 成交已 confirmed
        if not settlement_doc:
            # confirmed 但没产生 settlement(说明 bonus_yuan = 0)
            return (STAGE_COMPLETED, "done", False)

        stl_status = settlement_doc.get("status")
        if stl_status == "settled":
            return (STAGE_COMPLETED, "done", False)
        if stl_status in ("pending_payment", "pending_receipt"):
            return (STAGE_PAYMENT, "in_progress", False)
        if stl_status == "disputed":
            return (STAGE_PAYMENT, "failed", True)

        # 兜底
        return (STAGE_PAYMENT, "in_progress", False)

    # 没 transaction,看最新一条带看判态
    latest = showings[0]
    latest_status = latest.get("status")

    if latest_status == "rejected":
        # 鲁棒:历史有 confirmed 的不算 failed(下一次带看再来即可)
        if any(s.get("status") == "confirmed" for s in showings):
            return (STAGE_SHOWING, "done", False)
        return (STAGE_SHOWING, "failed", True)

    if latest_status == "pending_confirm":
        return (STAGE_SHOWING, "in_progress", False)

    # latest 是 confirmed 或其他正常态,带看已完成(等成交)
    return (STAGE_SHOWING, "done", False)


def _stage_status_label(stage, status, is_failed):
    """生成给前端的状态标签文字"""
    if is_failed:
        if status == "failed":
            return "失败"
        if status == "expired":
            return "已过期"
        return "已终止"
    if status == "in_progress":
        return f"{STAGE_LABELS[stage]}(进行中)"
    if status == "done" and stage == STAGE_COMPLETED:
        return "已完成"
    return STAGE_LABELS[stage]


# ============= 主聚合函数 =============

def list_my_collaborations(current_agent_id: str, role: str) -> list[dict]:
    """查我的协作列表(Day 15 起支持 1:N 带看)

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

    # 批量查关联的 showings(1:N — 一个 req 可能对应多条 showing)
    request_ids = [r["_id"] for r in requests]
    showings_by_req: dict = {}
    for s in (
        db["showings"]
        .find({"showing_request_id": {"$in": request_ids}})
        .sort("created_at", -1)  # 倒序:每个 req 的 showings 列表中最新的在前
    ):
        showings_by_req.setdefault(s["showing_request_id"], []).append(s)

    # 批量查关联的 transactions(可能挂在任何一条 showing 上,因此 flatten 取所有 showing_id)
    all_showing_ids = [
        s["_id"]
        for showing_list in showings_by_req.values()
        for s in showing_list
    ]
    transactions_by_showing = {}
    if all_showing_ids:
        for t in db["transactions"].find({"showing_id": {"$in": all_showing_ids}}):
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
        showings = showings_by_req.get(req["_id"], [])  # list,最新在前;可能为空
        latest_showing = showings[0] if showings else None

        # transaction 挂在某一条 showing 上,逐条扫:任一 showing 上有 tx 即算这个协作的 tx
        transaction = None
        for s in showings:
            t = transactions_by_showing.get(s["_id"])
            if t:
                transaction = t
                break

        settlement = (
            settlements_by_tx.get(transaction["_id"]) if transaction else None
        )

        stage, status, is_failed = _compute_stage(
            req, showings, transaction, settlement
        )

        # 找最近动作时间(用于排序和"最近动作"显示)
        last_time = req.get("updated_at") or req.get("created_at")
        last_action_text = "申请已发出"

        if showings:
            # 遍历所有带看,取最大 updated_at
            for s in showings:
                s_time = s.get("updated_at") or s.get("created_at")
                if s_time and (last_time is None or s_time > last_time):
                    last_time = s_time
            # 文案以最新一条为准,>1 次带看时加"第 N 次"前缀
            n = len(showings)
            prefix = f"第{n}次" if n > 1 else ""
            ls = latest_showing.get("status")
            if ls == "confirmed":
                last_action_text = f"{prefix}带看已确认"
            elif ls == "pending_confirm":
                last_action_text = f"{prefix}带看待 LA 确认"
            elif ls == "rejected":
                last_action_text = f"{prefix}带看被驳回"

        if transaction:
            t_time = transaction.get("updated_at") or transaction.get("created_at")
            if t_time and (last_time is None or t_time > last_time):
                last_time = t_time
            tx_status = transaction.get("status")
            if tx_status == "pending_la_confirm":
                last_action_text = "成交待 LA 填价"
            elif tx_status == "confirmed":
                last_action_text = "成交已生效"
            elif tx_status == "rejected":
                last_action_text = "成交被驳回"

        if settlement:
            stl_time = settlement.get("updated_at") or settlement.get("created_at")
            if stl_time and (last_time is None or stl_time > last_time):
                last_time = stl_time
            stl_status = settlement.get("status")
            if stl_status == "pending_payment":
                last_action_text = "等 LA 付款"
            elif stl_status == "pending_receipt":
                last_action_text = "等 BA 确认收款"
            elif stl_status == "settled":
                last_action_text = "结算完成"

        # 失败/过期态覆盖文案(申请态拒绝/过期单独处理)
        if is_failed:
            if req.get("status") == "rejected":
                # 拒绝理由中文映射(和后端 REJECT_REASONS 保持一致)
                reject_reason_map = {
                    "mismatch": "客户需求与房源不匹配",
                    "inconvenient": "近期不方便看房",
                    "near_deal": "房源即将成交",
                    "other": req.get("reject_extra") or "其他",
                }
                reason_text = reject_reason_map.get(
                    req.get("reject_reason") or "",
                    req.get("reject_reason") or "未填理由",
                )
                last_action_text = f"申请被拒 · {reason_text}"
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
            # Day 15 新增:带看次数(给前端"X 次带看"角标用,前端忽略也无影响)
            "showing_count": len(showings),
            # 跳转用的子对象 ID(showing_id 取最新一条;transaction/settlement 取唯一)
            "request_id": str(req["_id"]),
            "showing_id": str(latest_showing["_id"]) if latest_showing else None,
            "transaction_id": str(transaction["_id"]) if transaction else None,
            "transaction_status": transaction.get("status") if transaction else None,  # 协作 Tab 路由判断用
            "settlement_id": str(settlement["_id"]) if settlement else None,
        })

    # 按 last_action_time 降序
    result.sort(
        key=lambda x: x.get("last_action_time") or "",
        reverse=True,
    )
    return result