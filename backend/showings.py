"""
MLS 模块四续集 - 带看确认(交易留痕节点 ④)
作者:磊

MVP 范围:
- BA 提交带看记录:时间 + 照片(1-3 张 base64) + 备注
- LA 确认 / 驳回(带理由)
- 查询:按 request_id / showing_id 查、LA 待确认列表 + 角标

业务规则:
- 前置:showing_request.status = "approved"
- BA 权限:必须是申请的发起人
- LA 权限:必须是房源归属人
- 一申请同时只能有一条 pending_confirm 或 confirmed(rejected 可共存多条历史)
- listing_cycle 字段预留(模块五会用)

未覆盖(等对象存储 + 模块五):
- EXIF 拍摄时间校验 / GPS 位置校验
- 离线拍照排队
- 带看反馈表单
"""
from datetime import datetime, timedelta
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import db

showings_collection = db["showings"]
showing_requests_collection = db["showing_requests"]


# ==================== 数据模型 ====================

class CreateShowingBody(BaseModel):
    """BA 提交带看记录"""
    showing_request_id: str = Field(..., description="关联的带客申请 ID")
    showing_time: datetime = Field(..., description="实际带看时间(ISO)")
    photos: list[str] = Field(..., min_length=1, max_length=3,
                              description="现场照片 base64 data URL,1-3 张")
    notes: Optional[str] = Field(None, max_length=200, description="带看备注")


class RejectShowingBody(BaseModel):
    """LA 驳回带看"""
    reason: str = Field(..., min_length=1, max_length=100, description="驳回理由")


# ==================== 索引 ====================

def ensure_showings_indexes():
    showings_collection.create_index("showing_request_id")
    showings_collection.create_index("ba_agent_id")
    showings_collection.create_index("la_agent_id")
    showings_collection.create_index([("la_agent_id", 1), ("status", 1)])


# ==================== 工具 ====================

def _to_oid(s: str, detail: str = "无效的ID") -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail=detail)


def _naive(dt: datetime) -> datetime:
    """把 tz-aware 的 datetime 转成 tz-naive,避免 MongoDB 存储 + 比较踩坑"""
    if dt.tzinfo is not None:
        return dt.replace(tzinfo=None)
    return dt


# ==================== 业务函数 ====================

def submit_showing(body: CreateShowingBody, ba_agent: dict) -> dict:
    """BA 提交带看记录"""
    req_oid = _to_oid(body.showing_request_id, "无效的申请ID")
    req = showing_requests_collection.find_one({"_id": req_oid})
    if not req:
        raise HTTPException(status_code=404, detail="带客申请不存在")
    if req["buyer_agent_id"] != ba_agent["_id"]:
        raise HTTPException(status_code=403, detail="只有申请的发起人可以提交带看记录")
    if req["status"] != "approved":
        raise HTTPException(status_code=400, detail="该申请尚未通过审批,不能提交带看记录")

    # 带看时间不能晚于现在(允许 5 分钟时钟漂移)
    showing_time = _naive(body.showing_time)
    if showing_time > datetime.now() + timedelta(minutes=5):
        raise HTTPException(status_code=400, detail="带看时间不能晚于当前时间")

    # 一申请最多一条 pending_confirm 或 confirmed
    existing = showings_collection.find_one({
        "showing_request_id": req_oid,
        "status": {"$in": ["pending_confirm", "confirmed"]},
    })
    if existing:
        if existing["status"] == "pending_confirm":
            raise HTTPException(status_code=400, detail="已有带看记录正在等待 LA 确认")
        else:
            raise HTTPException(status_code=400, detail="该带客申请已有确认的带看记录")

    # 照片格式简单校验(data URL)
    for i, p in enumerate(body.photos):
        if not p or not p.startswith("data:image/"):
            raise HTTPException(status_code=400, detail=f"第 {i+1} 张照片格式错误")

    now = datetime.now()
    doc = {
        "showing_request_id": req_oid,
        "listing_id": req["listing_id"],
        "listing_snapshot": req.get("listing_snapshot", {}),
        "ba_agent_id": req["buyer_agent_id"],
        "ba_agent_name": req["buyer_agent_name"],
        "ba_agent_phone": req["buyer_agent_phone"],
        "la_agent_id": req["listing_agent_id"],
        "la_agent_name": req["listing_agent_name"],
        "showing_time": showing_time,
        "photos": body.photos,
        "photo_count": len(body.photos),
        "notes": (body.notes or "").strip(),
        "status": "pending_confirm",
        "reject_reason": None,
        "ba_submitted_at": now,
        "la_reviewed_at": None,
        "listing_cycle": None,  # 预留,模块五填
        "created_at": now,
        "updated_at": now,
    }
    result = showings_collection.insert_one(doc)
    return {"showing_id": str(result.inserted_id)}


def get_showing_by_id(showing_id: str, viewer_agent_id: ObjectId) -> dict:
    """按 showing_id 查详情(BA 或 LA 可见)"""
    oid = _to_oid(showing_id, "无效的带看ID")
    doc = showings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="带看记录不存在")
    if viewer_agent_id not in (doc["ba_agent_id"], doc["la_agent_id"]):
        raise HTTPException(status_code=403, detail="无权查看")
    return _format_showing(doc)


def get_showing_by_request(request_id: str, viewer_agent_id: ObjectId) -> Optional[dict]:
    """
    按 request_id 查最新的带看记录
    返回 None 表示还没有提交过
    """
    req_oid = _to_oid(request_id, "无效的申请ID")
    req = showing_requests_collection.find_one({"_id": req_oid})
    if not req:
        raise HTTPException(status_code=404, detail="带客申请不存在")
    if viewer_agent_id not in (req["buyer_agent_id"], req["listing_agent_id"]):
        raise HTTPException(status_code=403, detail="无权查看")

    doc = showings_collection.find_one(
        {"showing_request_id": req_oid},
        sort=[("created_at", -1)],
    )
    if not doc:
        return None
    return _format_showing(doc)


def confirm_showing(showing_id: str, la_agent_id: ObjectId) -> dict:
    """LA 确认带看"""
    oid = _to_oid(showing_id, "无效的带看ID")
    doc = showings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="带看记录不存在")
    if doc["la_agent_id"] != la_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以确认")
    if doc["status"] != "pending_confirm":
        raise HTTPException(status_code=400,
                            detail=f"当前状态不支持确认(status={doc['status']})")

    now = datetime.now()
    showings_collection.update_one(
        {"_id": oid, "status": "pending_confirm"},  # 乐观锁
        {"$set": {
            "status": "confirmed",
            "la_reviewed_at": now,
            "updated_at": now,
        }},
    )
    new_doc = showings_collection.find_one({"_id": oid})
    return _format_showing(new_doc)


def reject_showing(showing_id: str, body: RejectShowingBody,
                   la_agent_id: ObjectId) -> dict:
    """LA 驳回带看"""
    oid = _to_oid(showing_id, "无效的带看ID")
    doc = showings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="带看记录不存在")
    if doc["la_agent_id"] != la_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以驳回")
    if doc["status"] != "pending_confirm":
        raise HTTPException(status_code=400,
                            detail=f"当前状态不支持驳回(status={doc['status']})")

    reason = body.reason.strip()
    if not reason:
        raise HTTPException(status_code=400, detail="驳回理由不能为空")

    now = datetime.now()
    showings_collection.update_one(
        {"_id": oid, "status": "pending_confirm"},
        {"$set": {
            "status": "rejected",
            "reject_reason": reason,
            "la_reviewed_at": now,
            "updated_at": now,
        }},
    )
    new_doc = showings_collection.find_one({"_id": oid})
    return _format_showing(new_doc)


def list_pending_confirm(la_agent_id: ObjectId, skip: int = 0,
                         limit: int = 50) -> tuple[list, int]:
    """LA 视角:待我确认的带看列表"""
    query = {"la_agent_id": la_agent_id, "status": "pending_confirm"}
    total = showings_collection.count_documents(query)
    cursor = (
        showings_collection.find(query)
        .sort("ba_submitted_at", -1)
        .skip(skip)
        .limit(limit)
    )
    items = [_format_showing_lite(doc) for doc in cursor]
    return items, total


def count_pending_confirm(la_agent_id: ObjectId) -> int:
    """LA 工作台角标"""
    return showings_collection.count_documents({
        "la_agent_id": la_agent_id,
        "status": "pending_confirm",
    })


# ==================== 格式化器 ====================

def _format_showing(doc: dict) -> dict:
    """详情版:含完整 photos"""
    return {
        "showing_id": str(doc["_id"]),
        "showing_request_id": str(doc["showing_request_id"]),
        "listing_id": str(doc["listing_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),
        "ba_agent_name": doc.get("ba_agent_name", ""),
        "la_agent_name": doc.get("la_agent_name", ""),
        "showing_time": doc["showing_time"].isoformat(),
        "photos": doc.get("photos", []),
        "photo_count": doc.get("photo_count", 0),
        "notes": doc.get("notes", ""),
        "status": doc["status"],
        "reject_reason": doc.get("reject_reason"),
        "ba_submitted_at": doc["ba_submitted_at"].isoformat(),
        "la_reviewed_at": doc["la_reviewed_at"].isoformat()
        if doc.get("la_reviewed_at") else None,
    }


def _format_showing_lite(doc: dict) -> dict:
    """列表版:不返回 photos 大数据,只要缩略信息"""
    return {
        "showing_id": str(doc["_id"]),
        "showing_request_id": str(doc["showing_request_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),
        "ba_agent_name": doc.get("ba_agent_name", ""),
        "showing_time": doc["showing_time"].isoformat(),
        "photo_count": doc.get("photo_count", 0),
        "status": doc["status"],
        "ba_submitted_at": doc["ba_submitted_at"].isoformat(),
    }