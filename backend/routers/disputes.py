"""经纪人端举报路由(模块六 §7 的录入侧)。"""
from fastapi import APIRouter, Depends

from auth import get_current_agent
from disputes import FileDisputeBody, file_dispute

disputes_router = APIRouter(prefix="/api/v1", tags=["disputes"])


@disputes_router.post("/disputes")
def api_file_dispute(body: FileDisputeBody, agent: dict = Depends(get_current_agent)):
    """经纪人发起举报(对一笔成交或某经纪人)。"""
    return {"success": True, "data": file_dispute(body, agent)}
