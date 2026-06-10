"""Dashboard 路由 -- 拆自 main.py L997-1492"""
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query, HTTPException
from auth import get_current_agent
from database import db
from bson import ObjectId
from dashboard_v6 import get_dashboard_v6
from showing_requests import count_pending_received, count_my_sent_recent_changes
from showings import count_pending_confirm
from transactions import (
    count_pending_for_la,
    _count_la_pending_transactions,
    _count_ba_waiting_transactions,
)
from settlements import count_pending_for_me as count_pending_settlements_for_me
from services.listings import count_shared_listings

dashboard_router = APIRouter(prefix="/api/v1", tags=["dashboard"])


@dashboard_router.get("/dashboard/summary")
def dashboard_summary_api(agent: dict = Depends(get_current_agent)):
    """工作台 5 个数字"""
    agent_id = agent["_id"]

    my_on_sale = db["listings"].count_documents({
        "owner_agent_id": agent_id,
        "status": "on_sale",
    })

    # 共享库统计:总数 + 今日新增
    shared_total = count_shared_listings(agent_id, new_today=False)
    shared_new_today = count_shared_listings(agent_id, new_today=True)

    pending_approval = count_pending_received(agent_id)
    pending_confirm_showing = count_pending_confirm(agent_id)
    pending_confirm_transaction = count_pending_for_la(agent_id)
    pending_settlement = count_pending_settlements_for_me(agent_id)
    my_sent_recent_changes = count_my_sent_recent_changes(agent_id)

    return {
        "success": True,
        "data": {
            "my_on_sale_count": my_on_sale,
            "shared_total_count": shared_total,
            "shared_new_today_count": shared_new_today,
            "pending_approval_count": pending_approval,
            "pending_confirm_showing_count": pending_confirm_showing,
            "pending_confirm_transaction_count": pending_confirm_transaction,
            "pending_settlement_count": pending_settlement,
            "my_sent_recent_changes_count": my_sent_recent_changes,
        },
    }


@dashboard_router.get("/dashboard/v6")
def dashboard_v6_api(agent: dict = Depends(get_current_agent)):
    """V6 数据大屏聚合接口 — 7 张卡全部数据"""
    data = get_dashboard_v6(agent["_id"])
    return {"success": True, "data": data}


# ==================== 模块:工作台 Day 11 增强 ====================

@dashboard_router.get("/dashboard/todos")
def api_dashboard_todos(
    current_agent: dict = Depends(get_current_agent),
):
    """工作台 · 逐条待办列表(最多 5 类,每类最多 5 条)

    5 类:
    1. 待我审批的申请(LA 视角)
    2. 待我确认的带看(LA 视角)
    3. 待我确认的成交(LA 视角)
    4. 待我操作的奖金(LA / BA 都可能)
    5. 成交被驳回(BA 视角)
    """
    agent_id = current_agent["_id"]
    todos = []

    # --- 1. 待审批申请(LA) ---
    pending_reqs = list(db["showing_requests"].find(
        {"listing_agent_id": agent_id, "status": "pending"},
    ).sort("created_at", -1).limit(5))
    
    for r in pending_reqs:
        snapshot = r.get("listing_snapshot", {})
        todos.append({
            "type": "approval",
            "priority": "high",
            "icon": "person_add",
            "title": f"{r.get('buyer_agent_name', '同行')}申请带看{snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": f"客户:{r.get('customer_surname','')}{'先生' if r.get('customer_gender')=='male' else '女士'} · {r.get('requirements','')}",
            "action_route": f"/showing-request/{str(r['_id'])}",
            "created_at": r["created_at"].isoformat() if r.get("created_at") else None,
        })

    # --- 2. 待确认带看(LA) ---
    pending_shows = list(db["showings"].find(
        {"la_agent_id": agent_id, "status": "pending_confirm"},
    ).sort("created_at", -1).limit(5))

    for s in pending_shows:
        snapshot = s.get("listing_snapshot", {})
        todos.append({
            "type": "showing_confirm",
            "priority": "high",
            "icon": "rate_review",
            "title": f"带看待确认 · {snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": f"客户:{s.get('customer_surname','')}{'先生' if s.get('customer_gender')=='male' else '女士'} · {s.get('photo_count',0)} 张照片",
            "action_route": f"/showing/{str(s['_id'])}/confirm",
            "created_at": s["created_at"].isoformat() if s.get("created_at") else None,
        })

    # --- 3. 待确认成交(LA) ---
    pending_txs = list(db["transactions"].find(
        {"la_agent_id": agent_id, "status": "pending_la_confirm"},
    ).sort("created_at", -1).limit(5))

    for t in pending_txs:
        snapshot = t.get("listing_snapshot", {})
        todos.append({
            "type": "transaction_confirm",
            "priority": "high",
            "icon": "gavel",
            "title": f"成交待确认 · {snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": "请独立填写成交价格,与 BA 一致方可通过",
            "action_route": f"/transaction/{str(t['_id'])}",
            "created_at": t["created_at"].isoformat() if t.get("created_at") else None,
        })

    # --- 4. 待操作奖金(LA 付款 / BA 收款,都算) ---
    pending_settlements = list(db["settlements"].find({
        "$or": [
            {"la_agent_id": agent_id, "status": "pending_payment"},
            {"ba_agent_id": agent_id, "status": "pending_receipt"},
        ],
    }).sort("created_at", -1).limit(5))

    for stl in pending_settlements:
        my_role = "la" if stl.get("la_agent_id") == agent_id else "ba"
        action_text = "待你标记已付" if my_role == "la" else "待你确认收款"
        snapshot = stl.get("listing_snapshot", {})
        bonus = stl.get("bonus_yuan", 0)
        todos.append({
            "type": "settlement",
            "priority": "normal",
            "icon": "monetization_on",
            "title": f"奖金 ¥{bonus} · {snapshot.get('community','')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": action_text,
            "action_route": f"/settlements/{str(stl['_id'])}",
            "created_at": stl["created_at"].isoformat() if stl.get("created_at") else None,
        })

    # --- 5. 成交被驳回(BA) ---
    rejected_txs = list(db["transactions"].find(
        {"ba_agent_id": agent_id, "status": "rejected"},
    ).sort("created_at", -1).limit(5))

    for t in rejected_txs:
        snapshot = t.get("listing_snapshot", {})
        reject_reason = t.get("reject_reason", "")
        todos.append({
            "type": "transaction_rejected",
            "priority": "high",
            "icon": "edit",
            "title": f"成交确认被驳回,待修改重提 · {snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": reject_reason or "请修改后重新提交",
            "action_route": f"/transaction/{str(t['_id'])}",
            "created_at": t["created_at"].isoformat() if t.get("created_at") else None,
        })

    # --- 6. 待回答的问题(LA) ---
    pending_qna = list(db["qna_threads"].find(
        {"answerer_id": str(agent_id), "status": "pending"},
    ).sort("question_at", -1).limit(5))

    for q in pending_qna:
        listing = db["listings"].find_one({"_id": ObjectId(q["listing_id"])}) if q.get("listing_id") else None
        comm = listing.get("community", "") if listing else ""
        todos.append({
            "type": "answer_pending",
            "priority": "medium",
            "icon": "help_circle",
            "title": f'{q.get("asker_anonymous_name", "同行")} 对你的{comm}提问',
            "subtitle": f'问:{q["question"][:40]}{"..." if len(q.get("question",""))>40 else ""}',
            "action_route": f'/listing/{q["listing_id"]}/qna?highlight={q.get("thread_id","")}',
            "created_at": q["question_at"].isoformat() if q.get("question_at") else None,
        })

    # --- 7. 等待 LA 回答(BA) ---
    from qna import _count_ba_pending_questions
    my_pending = _count_ba_pending_questions(agent_id)
    if my_pending > 0:
        todos.append({
            "type": "question_pending",
            "priority": "normal",
            "icon": "help_circle",
            "title": f"等待 LA 回答你的提问 (共 {my_pending} 条)",
            "subtitle": "已提的问题 LA 回复后这里会更新",
            "action_route": "/my-questions",
            "created_at": None,
        })

    # --- 8. 待确认成交(LA) + 等待 LA 确认(BA) Day 37 ---
    from transactions import _count_la_pending_transactions, _count_ba_waiting_transactions
    la_pending = _count_la_pending_transactions(agent_id)
    if la_pending > 0:
        todos.append({
            "type": "transaction_pending_confirm",
            "priority": "high",
            "icon": "handshake",
            "title": f"待你确认成交 ({la_pending} 笔)",
            "subtitle": "BA 已提交成交信息,请独立填写你掌握的成交价与日期",
            "action_route": "/transactions/pending?filter=la",
            "created_at": None,
        })
    ba_waiting = _count_ba_waiting_transactions(agent_id)
    if ba_waiting > 0:
        todos.append({
            "type": "transaction_waiting_la",
            "priority": "medium",
            "icon": "hourglass_empty",
            "title": f"等待 LA 确认成交 ({ba_waiting} 笔)",
            "subtitle": "你已提交成交信息,等待房源归属人独立填价确认",
            "action_route": "/transactions/pending?filter=ba",
            "created_at": None,
        })

    return {
        "success": True,
        "data": {
            "todos": todos,
            "total": len(todos),
        },
    }


@dashboard_router.get("/dashboard/recent-events")
def api_dashboard_recent_events(
    current_agent: dict = Depends(get_current_agent),
):
    """工作台 · 过去 24h 内的事件流
    
    事件类型:
    - 我发出的申请被审批(approved / rejected / expired)
    - 我 LA 的房源被申请(新 pending)
    - 我提交的带看被 LA 确认 / 驳回
    - 我的成交被 LA 确认 / 驳回
    - 我的奖金被标记已付
    """
    agent_id = current_agent["_id"]
    now = datetime.now()
    cutoff = now - timedelta(hours=24)
    events = []

    # --- 1. 我发出的申请 · 过去 24h 有状态变化 ---
    my_sent_reviewed = list(db["showing_requests"].find({
        "buyer_agent_id": agent_id,
        "status": {"$in": ["approved", "rejected", "expired"]},
        "reviewed_at": {"$gte": cutoff},
    }).sort("reviewed_at", -1).limit(10))

    for r in my_sent_reviewed:
        status = r.get("status")
        snapshot = r.get("listing_snapshot", {})
        la_name = r.get("listing_agent_name", "同行")
        if status == "approved":
            text = f"{la_name} 通过了你对 {snapshot.get('community','')} 的申请"
            icon = "check_circle"
            color = "green"
        elif status == "rejected":
            text = f"{la_name} 拒绝了你对 {snapshot.get('community','')} 的申请"
            icon = "cancel"
            color = "red"
        else:  # expired
            text = f"对 {snapshot.get('community','')} 的申请已过期(7 天未处理)"
            icon = "timer_off"
            color = "grey"
        events.append({
            "type": "sent_request_reviewed",
            "icon": icon,
            "color": color,
            "text": text,
            "time": r["reviewed_at"].isoformat() if r.get("reviewed_at") else None,
            "route": f"/showing-request/{str(r['_id'])}",
        })

    # --- 2. 我 LA 的房源 · 过去 24h 被申请(新 pending) ---
    my_la_new = list(db["showing_requests"].find({
        "listing_agent_id": agent_id,
        "status": "pending",
        "created_at": {"$gte": cutoff},
    }).sort("created_at", -1).limit(10))

    for r in my_la_new:
        snapshot = r.get("listing_snapshot", {})
        events.append({
            "type": "received_request_new",
            "icon": "person_add",
            "color": "orange",
            "text": f"{r.get('buyer_agent_name','同行')} 申请带看你的 {snapshot.get('community','')}",
            "time": r["created_at"].isoformat() if r.get("created_at") else None,
            "route": f"/showing-request/{str(r['_id'])}",
        })

    # --- 3. 我提交的带看 · 24h 内被 LA 确认或驳回(BA 视角) ---
    my_ba_shows = list(db["showings"].find({
        "ba_agent_id": agent_id,
        "status": {"$in": ["confirmed", "rejected"]},
        "confirmed_at": {"$gte": cutoff},
    }).sort("confirmed_at", -1).limit(10))

    for s in my_ba_shows:
        snapshot = s.get("listing_snapshot", {})
        if s.get("status") == "confirmed":
            text = f"带看记录已确认 · {snapshot.get('community','')}"
            icon = "check_circle"
            color = "green"
        else:
            text = f"带看被驳回 · {snapshot.get('community','')}"
            icon = "cancel"
            color = "red"
        events.append({
            "type": "my_showing_reviewed",
            "icon": icon,
            "color": color,
            "text": text,
            "time": s["confirmed_at"].isoformat() if s.get("confirmed_at") else None,
            "route": f"/showing/{str(s['_id'])}/confirm",
        })

    # 按时间降序排,最多返 15 条
    events.sort(key=lambda e: e.get("time") or "", reverse=True)
    events = events[:15]

    return {
        "success": True,
        "data": {
            "events": events,
            "total": len(events),
        },
    }
