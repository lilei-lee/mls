"""带客申请路由 -- 拆自 main.py L709-775"""
from fastapi import APIRouter, Depends
from auth import get_current_agent
from showing_requests import (
    CreateShowingRequestBody, RejectRequestBody,
    create_showing_request, approve_showing_request,
    reject_showing_request, get_request_by_id,
    list_received_requests, list_sent_requests,
    count_pending_received,
)

showing_requests_router = APIRouter(prefix="/api/v1", tags=["showing-requests"])


@showing_requests_router.post("/showing-requests")
def create_showing_request_api(
    req: CreateShowingRequestBody,
    agent: dict = Depends(get_current_agent),
):
    result = create_showing_request(req, agent)
    print(f"\n👀 新带客申请: 客户{req.customer_surname} by {agent['name']}")
    return {"success": True, **result}


@showing_requests_router.get("/showing-requests/received")
def list_received_requests_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    items, total = list_received_requests(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@showing_requests_router.get("/showing-requests/sent")
def list_sent_requests_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    items, total = list_sent_requests(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@showing_requests_router.get("/showing-requests/pending-count")
def pending_count_api(agent: dict = Depends(get_current_agent)):
    count = count_pending_received(agent["_id"])
    return {"success": True, "count": count}


@showing_requests_router.get("/showing-requests/{request_id}")
def get_showing_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_request_by_id(request_id, agent["_id"])
    return {"success": True, "data": doc}


@showing_requests_router.post("/showing-requests/{request_id}/approve")
def approve_showing_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = approve_showing_request(request_id, agent["_id"])
    print(f"\n✅ 审批通过: 客户{doc['customer_surname']} by {agent['name']}")
    return {"success": True, "data": doc}


@showing_requests_router.post("/showing-requests/{request_id}/reject")
def reject_showing_request_api(
    request_id: str,
    body: RejectRequestBody,
    agent: dict = Depends(get_current_agent),
):
    doc = reject_showing_request(request_id, body, agent["_id"])
    print(f"\n❌ 审批拒绝: 客户{doc['customer_surname']} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}

