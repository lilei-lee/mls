"""经纪人端:发起房源归属变更申请(模块六 §5.3 录入侧)。

当前归属人发起 = 上传委托凭证 + 指定目标 + 理由 → 锁定房源,进后台复核队列。
复核/确认在后台(routers/admin.py)。
"""
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from auth import get_current_agent
from ownership import create_ownership_change

ownership_router = APIRouter(prefix="/api/v1", tags=["ownership"])


class RequestOwnershipChangeBody(BaseModel):
    listing_id: str = Field(..., min_length=1, description="房源 ID")
    to_phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="目标经纪人手机号")
    proof: Optional[str] = Field(None, description="委托凭证(base64 data url 或 key,可选)")
    reason: Optional[str] = Field(None, max_length=200, description="变更理由")


@ownership_router.post("/ownership-changes")
def api_request_ownership_change(body: RequestOwnershipChangeBody,
                                 agent: dict = Depends(get_current_agent)):
    """当前归属人发起归属变更申请。create_ownership_change 强制校验本人 + 全护栏。"""
    res = create_ownership_change(
        body.listing_id, body.to_phone, body.proof or "", body.reason or "",
        requester_agent_id=agent["_id"],
    )
    return {"success": True, "data": res}
