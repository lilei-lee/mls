"""
MLS 模块四 - 带客协作(MVP 版)
作者:磊

MVP 范围:
- 发起申请、审批(同意/拒绝)、详情查询
- 审批前匿名(双方互不知道对方身份)
- 审批后身份互通 + 解锁电话

未覆盖(后续填):
- 带看确认 / 现场拍照 / GPS
- 推送 / 微信分享 / 7天过期
- 暂停校验 / 自促成交 / 批量审批
"""
from datetime import datetime, timedelta
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import db, agents_collection

# 集合引用
showing_requests_collection = db["showing_requests"]
listings_collection = db["listings"]


# ==================== 数据模型 ====================

class CreateShowingRequestBody(BaseModel):
    """发起带客申请请求"""
    listing_id: str = Field(..., description="目标房源 ID")
    customer_surname: str = Field(..., min_length=1, max_length=5, description="客户姓氏")
    customer_gender: str = Field(..., description="客户性别:male/female")
    requirements: str = Field(..., min_length=1, max_length=200, description="购房需求")
    customer_id: str | None = Field(None, description="关联客户 ID(可选,老流程为 None 即纯扁平字段)")


class RejectRequestBody(BaseModel):
    """拒绝理由"""
    reason: str = Field(..., description="拒绝理由 key")
    extra: Optional[str] = Field(None, max_length=200, description="补充说明")


# 4 个预设拒绝理由
REJECT_REASONS = {
    "mismatch": "客户需求与房源不匹配",
    "inconvenient": "近期不方便看房",
    "near_deal": "房源即将成交",
    "other": "其他",
}


# ==================== 索引 ====================

def ensure_showing_indexes():
    """建立带客申请索引"""
    showing_requests_collection.create_index("buyer_agent_id")  # BA 查自己发的
    showing_requests_collection.create_index("listing_agent_id")  # LA 查我收到的
    showing_requests_collection.create_index("listing_id")
    showing_requests_collection.create_index("status")


# ==================== 业务函数 ====================

def create_showing_request(req: CreateShowingRequestBody, buyer_agent: dict) -> dict:
    """BA 发起带客申请"""
    # 1. 查房源
    try:
        listing = listings_collection.find_one({"_id": ObjectId(req.listing_id)})
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")
    # V2.1 #14: sold 专属文案,#15 楼盘辞典实施时改 property 维度
    if listing.get("status") == "sold":
        raise HTTPException(status_code=400, detail="该房源已成交,无法发起新协作")
    if listing.get("status") != "on_sale":
        raise HTTPException(status_code=400, detail="该房源当前不接受带客申请")

    # 2. 不能向自己的房源发起申请
    if listing["owner_agent_id"] == buyer_agent["_id"]:
        raise HTTPException(status_code=400, detail="不能对自己录入的房源发起带客申请")

    # 3. 校验性别
    if req.customer_gender not in ("male", "female"):
        raise HTTPException(status_code=400, detail="性别参数错误")

    # 3.5. 校验 customer_id(如果传了)
    if req.customer_id:
        from database import db
        try:
            customer_oid = ObjectId(req.customer_id)
        except Exception:
            raise HTTPException(status_code=400, detail="无效的客户 ID")
        customer_doc = db["customers"].find_one({"_id": customer_oid})
        if not customer_doc:
            raise HTTPException(status_code=404, detail="客户不存在")
        if customer_doc["owner_agent_id"] != buyer_agent["_id"]:
            raise HTTPException(status_code=403, detail="不能用他人的客户发起申请")

    # 4. 插入申请
    now = datetime.now()
    doc = {
        "listing_id": listing["_id"],
        "listing_snapshot": {
            "community": listing["community"],
            "building": listing["building"],
            "unit": listing["unit"],
            "room_no": listing["room_no"],
            "layout": listing.get("layout", ""),
            "area_sqm": listing["area_sqm"],
            "price_wan": listing["price_wan"],
        },
        "buyer_agent_id": buyer_agent["_id"],
        "buyer_agent_name": buyer_agent["name"],
        "buyer_agent_phone": buyer_agent["phone"],
        "buyer_agent_store": buyer_agent.get("store_name", ""),
        "listing_agent_id": listing["owner_agent_id"],
        "listing_agent_name": listing["owner_agent_name"],
        "listing_agent_phone": listing.get("owner_agent_phone", ""),
        "customer_surname": req.customer_surname.strip(),
        "customer_gender": req.customer_gender,
        "requirements": req.requirements.strip(),
        "customer_id": ObjectId(req.customer_id) if req.customer_id else None,
        "approval_kind": "manual",  # manual / auto_approved
        "status": "pending",  # pending / approved / rejected
        "reject_reason": None,
        "reject_extra": None,
        "created_at": now,
        "updated_at": now,
        "reviewed_at": None,
    }
    result = showing_requests_collection.insert_one(doc)
    return {"request_id": str(result.inserted_id)}


def approve_showing_request(request_id: str, current_agent_id: ObjectId) -> dict:
    """LA 审批通过"""
    try:
        oid = ObjectId(request_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的申请ID")

    doc = showing_requests_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="申请不存在")
    if doc["listing_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以审批")
    if doc["status"] != "pending":
        raise HTTPException(status_code=400, detail=f"该申请已处理,不能重复审批")

    now = datetime.now()
    showing_requests_collection.update_one(
        {"_id": oid},
        {"$set": {
            "status": "approved",
            "reviewed_at": now,
            "updated_at": now,
        }},
    )
    new_doc = showing_requests_collection.find_one({"_id": oid})
    return _format_request(new_doc, viewer_role="listing_agent")


def reject_showing_request(
    request_id: str,
    body: RejectRequestBody,
    current_agent_id: ObjectId,
) -> dict:
    """LA 审批拒绝"""
    try:
        oid = ObjectId(request_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的申请ID")

    if body.reason not in REJECT_REASONS:
        raise HTTPException(status_code=400, detail="拒绝理由无效")
    if body.reason == "other" and not (body.extra and body.extra.strip()):
        raise HTTPException(status_code=400, detail='选择"其他"时必须填写补充说明')

    doc = showing_requests_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="申请不存在")
    if doc["listing_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以审批")
    if doc["status"] != "pending":
        raise HTTPException(status_code=400, detail="该申请已处理,不能重复审批")

    now = datetime.now()
    showing_requests_collection.update_one(
        {"_id": oid},
        {"$set": {
            "status": "rejected",
            "reject_reason": body.reason,
            "reject_extra": body.extra.strip() if body.extra else None,
            "reviewed_at": now,
            "updated_at": now,
        }},
    )
    new_doc = showing_requests_collection.find_one({"_id": oid})
    return _format_request(new_doc, viewer_role="listing_agent")


def get_request_by_id(
    request_id: str,
    current_agent_id: ObjectId,
) -> dict:
    """查申请详情(自动判断 viewer 是 BA 还是 LA)"""
    try:
        oid = ObjectId(request_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的申请ID")

    doc = showing_requests_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="申请不存在")

    if doc["buyer_agent_id"] == current_agent_id:
        viewer_role = "buyer_agent"
    elif doc["listing_agent_id"] == current_agent_id:
        viewer_role = "listing_agent"
    else:
        raise HTTPException(status_code=403, detail="无权查看该申请")

    return _format_request(doc, viewer_role=viewer_role)


def list_received_requests(
    current_agent_id: ObjectId,
    skip: int = 0,
    limit: int = 50,
) -> tuple[list, int]:
    """LA 视角:我收到的带客申请(别人向我房源发的)"""
    query = {"listing_agent_id": current_agent_id}
    total = showing_requests_collection.count_documents(query)
    cursor = (
        showing_requests_collection.find(query)
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    items = [_format_request(doc, viewer_role="listing_agent") for doc in cursor]
    return items, total


def list_sent_requests(
    current_agent_id: ObjectId,
    skip: int = 0,
    limit: int = 50,
) -> tuple[list, int]:
    """BA 视角:我发出的带客申请"""
    query = {"buyer_agent_id": current_agent_id}
    total = showing_requests_collection.count_documents(query)
    cursor = (
        showing_requests_collection.find(query)
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    items = [_format_request(doc, viewer_role="buyer_agent") for doc in cursor]
    return items, total


def count_pending_received(current_agent_id: ObjectId) -> int:
    """LA 视角:待我审批的数量(用于工作台角标)"""
    return showing_requests_collection.count_documents({
        "listing_agent_id": current_agent_id,
        "status": "pending",
    })


def count_my_sent_recent_changes(current_agent_id: ObjectId, hours: int = 24) -> int:
    """BA 视角:过去 N 小时内,我发出的申请被 LA 审批(通过/驳回)的数量
    用于工作台"我发出的申请"角标提示。
    过了 N 小时自然消失,避免一直顶着。
    """
    since = datetime.now() - timedelta(hours=hours)
    return showing_requests_collection.count_documents({
        "buyer_agent_id": current_agent_id,
        "status": {"$in": ["approved", "rejected"]},
        "reviewed_at": {"$gte": since},
    })


# ==================== 格式化器 ====================

def _format_request(doc: dict, viewer_role: str) -> dict:
    """
    统一格式化输出,核心是身份可见性控制

    - viewer_role = 'listing_agent'(LA 看自己收到的)
      * 待审批状态:隐藏 BA 身份
      * 已批准:公开 BA 身份
      * 已拒绝:不公开 BA 身份(保持匿名)
    - viewer_role = 'buyer_agent'(BA 看自己发的)
      * 待审批状态:隐藏 LA 身份(匿名)
      * 已批准:公开 LA 身份
      * 已拒绝:不公开 LA 身份
    """
    status = doc["status"]
    approved = (status == "approved")

    result = {
        "request_id": str(doc["_id"]),
        "listing_id": str(doc["listing_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),
        "customer_surname": doc["customer_surname"],
        "customer_gender": doc["customer_gender"],
        "requirements": doc["requirements"],
        "status": status,
        "reject_reason": doc.get("reject_reason"),
        "reject_reason_text": REJECT_REASONS.get(doc.get("reject_reason") or "", None),
        "reject_extra": doc.get("reject_extra"),
        "created_at": doc["created_at"].isoformat(),
        "reviewed_at": doc["reviewed_at"].isoformat() if doc.get("reviewed_at") else None,
    }

    # 身份信息
    if viewer_role == "listing_agent":
        # LA 看自己,对方是 BA
        if approved:
            result["counterparty"] = {
                "role": "buyer_agent",
                "name": doc["buyer_agent_name"],
                "phone": doc["buyer_agent_phone"],
                "store": doc.get("buyer_agent_store", ""),
            }
        else:
            result["counterparty"] = {"role": "buyer_agent", "anonymous": True}
    else:
        # BA 看自己,对方是 LA
        if approved:
            result["counterparty"] = {
                "role": "listing_agent",
                "name": doc["listing_agent_name"],
                "phone": doc.get("listing_agent_phone", ""),
            }
        else:
            result["counterparty"] = {"role": "listing_agent", "anonymous": True}

    result["viewer_role"] = viewer_role
    return result