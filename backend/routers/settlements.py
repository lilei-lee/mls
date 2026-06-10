"""奖金结算路由 -- 拆自 main.py L1096-1139"""
from fastapi import APIRouter, Depends
from auth import get_current_agent
from settlements import (
    LaMarkPaidBody,
    la_mark_paid,
    get_by_id as get_settlement_by_id,
    list_pending_for_me as list_pending_settlements_for_me,
    count_pending_for_me as count_pending_settlements_for_me,
)

settlements_router = APIRouter(prefix="/api/v1", tags=["settlements"])



@settlements_router.get("/settlements/pending-my")
def list_pending_settlements_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    """待我处理的奖金结算单(LA 待付 / BA 待确认,合并返回)"""
    items, total = list_pending_settlements_for_me(
        agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@settlements_router.get("/settlements/pending-my-count")
def pending_settlements_count_api(
    agent: dict = Depends(get_current_agent),
):
    """工作台"待我操作奖金"角标数"""
    count = count_pending_settlements_for_me(agent["_id"])
    return {"success": True, "count": count}


@settlements_router.post("/settlements/{settlement_id}/la-mark-paid")
def la_mark_paid_api(
    settlement_id: str,
    body: LaMarkPaidBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 标记"我已付款" → pending_payment 转 pending_receipt"""
    doc = la_mark_paid(settlement_id, body, agent["_id"])
    return {"success": True, "data": doc}


@settlements_router.get("/settlements/{settlement_id}")
def get_settlement_api(
    settlement_id: str,
    agent: dict = Depends(get_current_agent),
):
    """结算单详情(viewer-aware)"""
    doc = get_settlement_by_id(settlement_id, agent["_id"])
    return {"success": True, "data": doc}

