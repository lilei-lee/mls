"""成交确认路由 -- 拆自 main.py L864-995"""
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from auth import get_current_agent
from database import db
from bson import ObjectId
from transactions import (
    InitiateTransactionBody, LaConfirmTransactionBody,
    LaRejectTransactionBody, UpdateMyTransactionBody,
    LaUpdateMySubmissionBody, CancelTransactionBody,
    initiate_transaction, la_confirm_transaction,
    la_reject_transaction, update_my_transaction,
    update_my_submission_la, cancel_transaction,
    get_by_id as get_transaction_by_id,
    get_by_showing as get_transaction_by_showing,
    list_pending_for_la, count_pending_for_la,
)

transactions_router = APIRouter(prefix="/api/v1", tags=["transactions"])

# ⚠️ 具体路径必须先注册

@transactions_router.post("/transactions")
def initiate_transaction_api(
    body: InitiateTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """BA 发起成交确认"""
    result = initiate_transaction(body, agent)
    print(f"\n💰 新成交确认发起: tx={result['transaction_id']} by {agent['name']}")
    return {"success": True, **result}


@transactions_router.get("/transactions/pending")
def list_pending_tx_api(
    skip: int = 0,
    limit: int = 50,
    filter: str | None = Query(None, description="la(默认)=LA视角待确认 / ba=BA视角等待LA"),
    agent: dict = Depends(get_current_agent),
):
    """成交待办列表:filter=la→LA确认, filter=ba→BA等待"""
    if filter == "ba":
        from transactions import get_waiting_la_listings
        total, docs = get_waiting_la_listings(agent["_id"], skip=skip, limit=limit)
        return {"success": True, "total": total, "items": [_format_transaction_lite(d) for d in docs]}
    items, total = list_pending_for_la(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@transactions_router.get("/transactions/pending-count")
def pending_tx_count_api(filter: str | None = Query(None), agent: dict = Depends(get_current_agent)):
    from transactions import _count_la_pending_transactions, _count_ba_waiting_transactions
    if filter == "ba":
        return {"success": True, "count": _count_ba_waiting_transactions(agent["_id"])}
    return {"success": True, "count": _count_la_pending_transactions(agent["_id"])}


@transactions_router.get("/transactions/by-showing/{showing_id}")
def get_transaction_by_showing_api(
    showing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """按带看查成交(可能 null)"""
    doc = get_transaction_by_showing(showing_id, agent["_id"])
    return {"success": True, "data": doc}


@transactions_router.post("/transactions/{transaction_id}/la-confirm")
def la_confirm_transaction_api(
    transaction_id: str,
    body: LaConfirmTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 独立填价 + 自动比对"""
    doc = la_confirm_transaction(transaction_id, body, agent["_id"])
    if doc["status"] == "confirmed":
        print(f"\n🎉 成交确认通过: tx={transaction_id} by {agent['name']}")
    else:
        print(f"\n⚠️  成交确认价格不一致自动驳回: tx={transaction_id}")
    return {"success": True, "data": doc}


@transactions_router.post("/transactions/{transaction_id}/la-reject")
def la_reject_transaction_api(
    transaction_id: str,
    body: LaRejectTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 手动驳回"""
    doc = la_reject_transaction(transaction_id, body, agent["_id"])
    print(f"\n❌ 成交手动驳回: tx={transaction_id} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


@transactions_router.patch("/transactions/{transaction_id}/my-submission")
def update_my_transaction_api(
    transaction_id: str,
    body: UpdateMyTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """BA/LA 修改自己的填报并重提

    根据 caller 身份自动路由:
    - BA: 改 ba_deal_price_yuan / ba_deal_date,清掉 LA 旧值,重提 pending_la_confirm
    - LA: 改 la_deal_price_yuan / la_deal_date,复用比对逻辑
    """
    # 先查 doc 判身份(无法从 body 区分 BA/LA)
    tx = db["transactions"].find_one({"_id": ObjectId(transaction_id)})
    if not tx:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if agent["_id"] == tx["ba_agent_id"]:
        doc = update_my_transaction(transaction_id, body, agent["_id"])
        print(f"\n✏️  成交记录修改重提(BA): tx={transaction_id} by {agent['name']}")
    elif agent["_id"] == tx["la_agent_id"]:
        if body.deal_price_yuan is None or body.deal_date is None:
            raise HTTPException(
                status_code=400,
                detail="修改填报需同时提供 deal_price_yuan 和 deal_date",
            )
        la_body = LaUpdateMySubmissionBody(
            la_deal_price_yuan=body.deal_price_yuan,
            la_deal_date=body.deal_date,
        )
        doc = update_my_submission_la(transaction_id, la_body, agent["_id"])
        print(f"\n✏️  成交记录修改重提(LA): tx={transaction_id} by {agent['name']}")
    else:
        raise HTTPException(status_code=403, detail="无权修改此成交记录")
    return {"success": True, "data": doc}


@transactions_router.post("/transactions/{transaction_id}/cancel")
def cancel_transaction_api(
    transaction_id: str,
    body: CancelTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """BA 撤回"""
    doc = cancel_transaction(transaction_id, body, agent["_id"])
    print(f"\n🚫 成交已撤回: tx={transaction_id} by {agent['name']}")
    return {"success": True, "data": doc}


@transactions_router.get("/transactions/{transaction_id}")
def get_transaction_api(
    transaction_id: str,
    agent: dict = Depends(get_current_agent),
):
    """成交详情(BA 或 LA)"""
    doc = get_transaction_by_id(transaction_id, agent["_id"])
    return {"success": True, "data": doc}

