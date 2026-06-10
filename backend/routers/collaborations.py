"""协作路由 -- 拆自 main.py L1494-1513"""
from fastapi import APIRouter, HTTPException, Depends
from auth import get_current_agent
from collaborations import list_my_collaborations

collaborations_router = APIRouter(prefix="/api/v1", tags=["collaborations"])

@collaborations_router.get("/collaborations/mine")
def api_list_my_collaborations(
    role: str,
    current_agent: dict = Depends(get_current_agent),
):
    """查我的协作列表(协作 = 一条申请 + 关联的带看/成交/结算)
    
    role 参数:
    - buyer: 我作为 BA 的协作
    - seller: 我作为 LA 的协作
    """
    if role not in ("buyer", "seller"):
        raise HTTPException(
            status_code=400, detail="role 必须是 buyer 或 seller"
        )
    items = list_my_collaborations(str(current_agent["_id"]), role)
    return {
        "success": True,
        "data": {"items": items, "total": len(items)},
    }