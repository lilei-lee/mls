"""带看记录路由 -- 拆自 main.py L777-861"""
from fastapi import APIRouter, HTTPException, Depends, Query
from auth import get_current_agent, get_unsuspended_agent
from showings import (
    CreateShowingBody, RejectShowingBody,
    submit_showing, get_showing_by_id, get_showing_by_request,
    confirm_showing, reject_showing, list_pending_confirm,
    count_pending_confirm,
)
from customers import can_direct_showing, DirectShowingRequest, create_direct_showing

showings_router = APIRouter(prefix="/api/v1", tags=["showings"])


@showings_router.post("/showings")
def submit_showing_api(
    body: CreateShowingBody,
    agent: dict = Depends(get_unsuspended_agent),
):
    result = submit_showing(body, agent)
    print(f"\n📸 新带看记录: showing_id={result['showing_id']} by {agent['name']}")
    return {"success": True, **result}


@showings_router.get("/showings/pending-confirm")
def list_pending_confirm_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    items, total = list_pending_confirm(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@showings_router.get("/showings/pending-confirm-count")
def pending_confirm_count_api(agent: dict = Depends(get_current_agent)):
    count = count_pending_confirm(agent["_id"])
    return {"success": True, "count": count}


@showings_router.get("/showings/by-request/{request_id}")
def get_showing_by_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_showing_by_request(request_id, agent["_id"])
    return {"success": True, "data": doc}


@showings_router.post("/showings/{showing_id}/confirm")
def confirm_showing_api(
    showing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = confirm_showing(showing_id, agent["_id"])
    print(f"\n✔️  带看已确认: showing_id={showing_id} by {agent['name']}")
    return {"success": True, "data": doc}


@showings_router.post("/showings/{showing_id}/reject")
def reject_showing_api(
    showing_id: str,
    body: RejectShowingBody,
    agent: dict = Depends(get_current_agent),
):
    doc = reject_showing(showing_id, body, agent["_id"])
    print(f"\n⏪ 带看驳回: showing_id={showing_id} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


# 具体路径必须先于 {showing_id} 注册(坑 3: FastAPI 路由顺序)
# 否则 "can-direct" / "direct" 会被 {showing_id} 吞掉当 OID 解析
@showings_router.get("/showings/can-direct")
def api_can_direct_showing(
    listing_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """检查能否对某房直接发起带看(熟人专用)"""
    data = can_direct_showing(str(current_agent["_id"]), listing_id)
    return {"success": True, "data": data}

@showings_router.post("/showings/direct")
def api_create_direct_showing(
    req: DirectShowingRequest,
    current_agent: dict = Depends(get_unsuspended_agent),
):
    """直接发起带看(跳过申请) · 前置:对这套房历史有 approved 申请"""
    data = create_direct_showing(str(current_agent["_id"]), req)
    return {"success": True, "data": data}

@showings_router.get("/showings/{showing_id}")
def get_showing_api(
    showing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_showing_by_id(showing_id, agent["_id"])
    return {"success": True, "data": doc}
