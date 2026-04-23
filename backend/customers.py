"""
MLS 模块:客户管理(Day 10 新建)

职责:
- 客户档案 CRUD(owner_agent_id 归属 BA)
- 跟进记录(memo_entries)
- 客户时间线(关联协作)

设计原则:轻量,只为"不忘事"服务,不做重 CRM
"""

from datetime import datetime
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import db


# ============= 集合索引 =============

def ensure_customers_indexes():
    """建索引:owner_agent_id(归属查询)+ created_at"""
    customers = db["customers"]
    customers.create_index("owner_agent_id")
    customers.create_index([("owner_agent_id", 1), ("status", 1)])
    customers.create_index("created_at")


# ============= Pydantic 模型 =============

class CreateCustomerRequest(BaseModel):
    surname: str = Field(..., min_length=1, max_length=10, description="客户姓氏")
    gender: str = Field(..., pattern="^(male|female)$", description="性别")
    phone: Optional[str] = Field(None, pattern=r"^1[3-9]\d{9}$", description="手机号(可选)")
    requirements: Optional[str] = Field(None, max_length=200, description="需求简述")


# ============= 辅助函数 =============

def _format_customer(doc: dict) -> dict:
    """格式化客户文档给前端"""
    return {
        "customer_id": str(doc["_id"]),
        "surname": doc.get("surname", ""),
        "gender": doc.get("gender", ""),
        "phone": doc.get("phone") or "",
        "requirements": doc.get("requirements") or "",
        "memo_entries": doc.get("memo_entries", []),
        "status": doc.get("status", "active"),
        "created_at": doc["created_at"].isoformat() if doc.get("created_at") else None,
        "updated_at": doc["updated_at"].isoformat() if doc.get("updated_at") else None,
    }


# ============= 业务函数 =============

def create_customer(current_agent_id: str, req: CreateCustomerRequest) -> dict:
    """BA 创建一个新客户"""
    now = datetime.now()
    doc = {
        "owner_agent_id": ObjectId(current_agent_id),
        "surname": req.surname.strip(),
        "gender": req.gender,
        "phone": req.phone,
        "requirements": (req.requirements or "").strip(),
        "memo_entries": [],
        "status": "active",
        "created_at": now,
        "updated_at": now,
    }
    result = db["customers"].insert_one(doc)
    doc["_id"] = result.inserted_id
    return _format_customer(doc)


def list_my_customers(current_agent_id: str) -> list[dict]:
    """BA 查自己的客户列表,按 updated_at 降序"""
    cursor = db["customers"].find(
        {"owner_agent_id": ObjectId(current_agent_id)}
    ).sort("updated_at", -1)
    return [_format_customer(doc) for doc in cursor]


def count_my_customers(current_agent_id: str) -> int:
    """BA 客户总数(active 状态)"""
    return db["customers"].count_documents({
        "owner_agent_id": ObjectId(current_agent_id),
        "status": "active",
    })
def get_customer_by_id(current_agent_id: str, customer_id: str) -> dict:
    """查客户详情(只能查自己的)"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权查看他人客户")
    return _format_customer(doc)


class UpdateCustomerRequest(BaseModel):
    surname: Optional[str] = Field(None, min_length=1, max_length=10)
    gender: Optional[str] = Field(None, pattern="^(male|female)$")
    phone: Optional[str] = Field(None, pattern=r"^1[3-9]\d{9}$")
    requirements: Optional[str] = Field(None, max_length=200)


def update_customer(
    current_agent_id: str,
    customer_id: str,
    req: UpdateCustomerRequest,
) -> dict:
    """更新客户基础信息"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权修改他人客户")

    # 只更新传了的字段
    updates = {}
    if req.surname is not None:
        updates["surname"] = req.surname.strip()
    if req.gender is not None:
        updates["gender"] = req.gender
    if req.phone is not None:
        updates["phone"] = req.phone
    if req.requirements is not None:
        updates["requirements"] = req.requirements.strip()

    if not updates:
        return _format_customer(doc)  # 空 PATCH 返回当前状态

    updates["updated_at"] = datetime.now()
    db["customers"].update_one({"_id": oid}, {"$set": updates})

    doc = db["customers"].find_one({"_id": oid})
    return _format_customer(doc)


class AddMemoRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500, description="跟进记录内容")


def add_memo(current_agent_id: str, customer_id: str, req: AddMemoRequest) -> dict:
    """添加一条跟进记录"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人客户")

    now = datetime.now()
    memo = {
        "text": req.text.strip(),
        "created_at": now.isoformat(),
    }
    db["customers"].update_one(
        {"_id": oid},
        {
            "$push": {"memo_entries": memo},
            "$set": {"updated_at": now},
        },
    )
    doc = db["customers"].find_one({"_id": oid})
    return _format_customer(doc)


def close_customer(current_agent_id: str, customer_id: str) -> dict:
    """标记客户为已结单"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人客户")

    db["customers"].update_one(
        {"_id": oid},
        {"$set": {"status": "closed", "updated_at": datetime.now()}},
    )
    doc = db["customers"].find_one({"_id": oid})
    return _format_customer(doc)


def get_customer_timeline(current_agent_id: str, customer_id: str) -> dict:
    """查客户时间线:关联的申请 / 带看 / 成交(按时间倒序)"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    customer = db["customers"].find_one({"_id": oid})
    if not customer:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(customer["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权查看他人客户")

    # 查关联的带客申请(通过 customer_id 字段)
    requests = list(db["showing_requests"].find({"customer_id": oid}))

    # 查关联的带看(通过申请反查)
    request_ids = [r["_id"] for r in requests]
    showings = list(
        db["showings"].find({"showing_request_id": {"$in": request_ids}})
    ) if request_ids else []

    # 查关联的成交
    showing_ids = [s["_id"] for s in showings]
    transactions = list(
        db["transactions"].find({"showing_id": {"$in": showing_ids}})
    ) if showing_ids else []

    # 聚合事件流:{type, time, data}
    events = []

    for r in requests:
        events.append({
            "type": "request",
            "time": r["created_at"].isoformat() if r.get("created_at") else None,
            "status": r.get("status"),
            "listing_snapshot": r.get("listing_snapshot", {}),
            "request_id": str(r["_id"]),
        })

    for s in showings:
        events.append({
            "type": "showing",
            "time": s["created_at"].isoformat() if s.get("created_at") else None,
            "status": s.get("status"),
            "showing_id": str(s["_id"]),
            "customer_feedback": s.get("customer_feedback", ""),
            "showing_time": s["showing_time"].isoformat() if s.get("showing_time") else None,
        })

    for t in transactions:
        events.append({
            "type": "transaction",
            "time": t["created_at"].isoformat() if t.get("created_at") else None,
            "status": t.get("status"),
            "transaction_id": str(t["_id"]),
        })

    # 时间倒序
    events.sort(key=lambda e: e.get("time") or "", reverse=True)

    return {
        "customer": _format_customer(customer),
        "events": events,
        "stats": {
            "requests_count": len(requests),
            "showings_count": len(showings),
            "transactions_count": len(transactions),
        },
    }


# ============= 熟人判断(直接带看前置) =============

def can_direct_showing(current_agent_id: str, listing_id: str) -> dict:
    """检查能否对某房直接发起带看
    
    规则(B 版本):针对同一套房,历史上有过 approved 的申请即可。
    """
    try:
        listing_oid = ObjectId(listing_id)
        agent_oid = ObjectId(current_agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID格式错误")

    # 查历史是否对这套房有过 approved 申请(或 auto_approved)
    history = db["showing_requests"].find_one({
        "listing_id": listing_oid,
        "buyer_agent_id": agent_oid,
        "status": {"$in": ["approved", "auto_approved"]},
    })

    if history:
        # 获取 LA 信息(已解密)
        la_doc = db["agents"].find_one({"_id": history.get("listing_agent_id")})
        return {
            "can_direct": True,
            "listing_agent": {
                "agent_id": str(la_doc["_id"]) if la_doc else "",
                "name": la_doc.get("name", "") if la_doc else "",
                "phone": la_doc.get("phone", "") if la_doc else "",
            } if la_doc else None,
            "first_approved_at": history["created_at"].isoformat() if history.get("created_at") else None,
        }
    else:
        return {
            "can_direct": False,
            "reason": "首次对接该房源,请先走申请流程",
        }