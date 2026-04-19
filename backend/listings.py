"""
MLS 模块二 - 房源管理
作者:磊
"""
import hashlib
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from bson import ObjectId
from database import db

# MongoDB 房源集合
listings_collection = db["listings"]


def generate_house_code(community: str, building: str, unit: str, room_no: str) -> str:
    """
    根据小区+楼号+单元+门牌号生成"一户一码"
    - 去除空格后拼接 + MD5 哈希 → 前16位作为 house_code
    - 同一套房不同经纪人录入会得到相同的 code,用于查重
    """
    raw = f"{community.strip()}#{building.strip()}#{unit.strip()}#{room_no.strip()}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:16]


# ==================== 数据模型 ====================

class CreateListingRequest(BaseModel):
    """创建房源请求"""
    community: str = Field(..., min_length=1, max_length=50, description="小区名")
    building: str = Field(..., min_length=1, max_length=20, description="楼号")
    unit: str = Field(..., min_length=1, max_length=10, description="单元号")
    room_no: str = Field(..., min_length=1, max_length=10, description="门牌号")
    area_sqm: float = Field(..., gt=0, le=2000, description="建筑面积(㎡)")
    layout: str = Field(..., max_length=30, description="户型,如 2室1厅1卫")
    floor: int = Field(..., ge=-5, le=200, description="所在楼层")
    total_floor: int = Field(..., ge=1, le=200, description="总楼层")
    orientation: str = Field(..., max_length=20, description="朝向,如 南北通透")
    price_wan: float = Field(..., gt=0, description="报价(万元)")
    remarks: Optional[str] = Field(None, max_length=500, description="备注")


class CreateListingResponse(BaseModel):
    success: bool
    listing_id: str
    house_code: str
    message: str


class ListingDuplicateError(BaseModel):
    """重复录入的响应"""
    success: bool = False
    detail: str
    existing_agent_name: str
    existing_agent_phone: str
    created_at: str


# ==================== 业务函数 ====================

def create_listing(req: CreateListingRequest, agent: dict) -> dict:
    """
    创建房源,返回新房源的完整信息
    - 生成一户一码
    - 检查重复:同 house_code 已存在 → 抛异常告知已被谁录入
    - 插入 MongoDB
    """
    from fastapi import HTTPException

    # 1. 生成一户一码
    house_code = generate_house_code(
        req.community, req.building, req.unit, req.room_no
    )

    # 2. 查重
    existing = listings_collection.find_one({"house_code": house_code})
    if existing:
        raise HTTPException(
            status_code=409,
            detail={
                "message": f"该房源已被 {existing['owner_agent_name']} 录入",
                "existing_agent_name": existing["owner_agent_name"],
                "existing_agent_phone": existing.get("owner_agent_phone", ""),
                "created_at": existing["created_at"].isoformat(),
            },
        )

    # 3. 组装文档
    now = datetime.now()
    doc = {
        "house_code": house_code,
        "community": req.community.strip(),
        "building": req.building.strip(),
        "unit": req.unit.strip(),
        "room_no": req.room_no.strip(),
        "area_sqm": req.area_sqm,
        "layout": req.layout,
        "floor": req.floor,
        "total_floor": req.total_floor,
        "orientation": req.orientation,
        "price_wan": req.price_wan,
        "remarks": req.remarks or "",
        "status": "on_sale",  # 默认在售
        "owner_agent_id": agent["_id"],
        "owner_agent_name": agent["name"],
        "owner_agent_phone": agent["phone"],
        "created_at": now,
        "updated_at": now,
    }

    # 4. 插入数据库
    result = listings_collection.insert_one(doc)

    return {
        "listing_id": str(result.inserted_id),
        "house_code": house_code,
    }


def ensure_indexes():
    """建立索引(启动时调用一次),提高查询性能和保证一户一码唯一"""
    # house_code 唯一索引 - 从数据库层面保证一户一码
    listings_collection.create_index("house_code", unique=True)
    # 按录入经纪人查询的索引(以后列表页用)
    listings_collection.create_index("owner_agent_id")
    # 按小区查询的索引
    listings_collection.create_index("community")

    # ==================== 列表查询函数 ====================

def list_my_listings(agent_id: ObjectId, skip: int = 0, limit: int = 20) -> list:
    """
    查询某经纪人自己录入的所有房源
    - 按创建时间倒序(最新的在前)
    - 支持分页
    """
    cursor = (
        listings_collection.find({"owner_agent_id": agent_id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    results = []
    for doc in cursor:
        results.append(_format_listing(doc))
    return results


def count_my_listings(agent_id: ObjectId) -> int:
    """统计某经纪人的房源总数"""
    return listings_collection.count_documents({"owner_agent_id": agent_id})


def _format_listing(doc: dict) -> dict:
    """把 MongoDB 文档转成前端友好的 JSON 格式"""
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "community": doc["community"],
        "building": doc["building"],
        "unit": doc["unit"],
        "room_no": doc["room_no"],
        "area_sqm": doc["area_sqm"],
        "layout": doc["layout"],
        "floor": doc["floor"],
        "total_floor": doc["total_floor"],
        "orientation": doc["orientation"],
        "price_wan": doc["price_wan"],
        "remarks": doc.get("remarks", ""),
        "status": doc.get("status", "on_sale"),
        "owner_agent_id": str(doc["owner_agent_id"]),
        "owner_agent_name": doc["owner_agent_name"],
        "owner_agent_phone": doc.get("owner_agent_phone", ""),
        "created_at": doc["created_at"].isoformat(),
        "updated_at": doc["updated_at"].isoformat(),
    }

# ==================== 共享房源库(匿名) ====================

def list_shared_listings(
    current_agent_id: ObjectId,
    skip: int = 0,
    limit: int = 20,
) -> list:
    """
    查询共享房源库:其他经纪人录入的在售房源(不含自己的)
    - 匿名展示:不返回录入经纪人的身份信息
    - 只展示 status='on_sale' 的房源
    - 按创建时间倒序
    """
    cursor = (
        listings_collection.find({
            "status": "on_sale",
            "owner_agent_id": {"$ne": current_agent_id},  # 排除自己的
        })
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    results = []
    for doc in cursor:
        results.append(_format_listing_anonymous(doc))
    return results


def count_shared_listings(current_agent_id: ObjectId) -> int:
    """统计共享库房源总数(不含自己)"""
    return listings_collection.count_documents({
        "status": "on_sale",
        "owner_agent_id": {"$ne": current_agent_id},
    })


def _format_listing_anonymous(doc: dict) -> dict:
    """
    匿名版格式化 - 不返回 owner 相关字段
    这是一个关键的安全设计:在浏览阶段,经纪人不应该看到对方是谁
    """
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "community": doc["community"],
        "building": doc["building"],
        "unit": doc["unit"],
        "room_no": doc["room_no"],
        "area_sqm": doc["area_sqm"],
        "layout": doc["layout"],
        "floor": doc["floor"],
        "total_floor": doc["total_floor"],
        "orientation": doc["orientation"],
        "price_wan": doc["price_wan"],
        "remarks": doc.get("remarks", ""),
        "status": doc.get("status", "on_sale"),
        # 注意:不返回 owner_agent_id、owner_agent_name、owner_agent_phone
        "created_at": doc["created_at"].isoformat(),
    }

# ==================== 单条查询 / 更新 / 下架 ====================

def get_listing_by_id(listing_id: str) -> dict | None:
    """根据 ID 查询单条房源"""
    try:
        doc = listings_collection.find_one({"_id": ObjectId(listing_id)})
    except Exception:
        return None
    if not doc:
        return None
    return _format_listing(doc)


def update_listing(
    listing_id: str,
    update_fields: dict,
    current_agent_id: ObjectId,
) -> dict:
    """
    更新房源(仅限本人录入的)
    - 只允许更新这些字段:layout, floor, total_floor, orientation, price_wan, remarks
    - 地址类字段不能改(community, building, unit, room_no)——改了相当于换了一套房,应该重录
    """
    from fastapi import HTTPException

    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    # 1. 查房源
    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")

    # 2. 检查归属
    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权修改他人的房源")

    # 3. 检查状态 — 已下架的不能再编辑
    if doc.get("status") == "offline":
        raise HTTPException(status_code=400, detail="已下架的房源不能编辑")

    # 4. 白名单字段过滤(只允许这些字段被更新)
    allowed = {"layout", "floor", "total_floor", "orientation", "price_wan", "remarks"}
    clean_fields = {k: v for k, v in update_fields.items() if k in allowed and v is not None}

    if not clean_fields:
        raise HTTPException(status_code=400, detail="没有有效的更新字段")

    clean_fields["updated_at"] = datetime.now()

    # 5. 执行更新
    listings_collection.update_one({"_id": oid}, {"$set": clean_fields})

    # 6. 返回最新数据
    new_doc = listings_collection.find_one({"_id": oid})
    return _format_listing(new_doc)


def offline_listing(listing_id: str, current_agent_id: ObjectId) -> dict:
    """
    下架房源(软删除)
    - 只是把 status 改成 offline,数据保留
    - 只能下架本人录入的
    """
    from fastapi import HTTPException

    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")

    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权下架他人的房源")

    if doc.get("status") == "offline":
        raise HTTPException(status_code=400, detail="房源已下架")

    listings_collection.update_one(
        {"_id": oid},
        {"$set": {"status": "offline", "updated_at": datetime.now()}},
    )

    new_doc = listings_collection.find_one({"_id": oid})
    return _format_listing(new_doc)

# ==================== 重新上架 ====================

def reactivate_listing(listing_id: str, current_agent_id: ObjectId) -> dict:
    """
    把已下架的房源重新上架(status: offline -> on_sale)
    - 只能操作本人的
    - 只能对 offline 状态的使用
    """
    from fastapi import HTTPException

    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")

    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人的房源")

    if doc.get("status") != "offline":
        raise HTTPException(status_code=400, detail="只有已下架的房源可以重新上架")

    listings_collection.update_one(
        {"_id": oid},
        {"$set": {"status": "on_sale", "updated_at": datetime.now()}},
    )

    new_doc = listings_collection.find_one({"_id": oid})
    return _format_listing(new_doc)