"""
MLS 模块二 - 房源管理
作者:磊

V2 升级:
- 新增结构化字段:district(行政区)、rooms(卧室)、halls(客厅)、bathrooms(卫生间)
- 保留原 layout 字段(如"2室1厅1卫"),方便展示
- 提供张家口行政区字典
"""
import hashlib
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field
from bson import ObjectId
from database import db

# MongoDB 房源集合
listings_collection = db["listings"]


# ==================== 张家口行政区字典 ====================

# 默认展示的行政区(筛选 Chip 顺序)
ZJK_DISTRICTS = [
    "桥东区",
    "桥西区",
    "宣化区",
    "下花园区",
    "万全区",
    "崇礼区",
    "怀来县",
    "涿鹿县",
    "其他",
]


def get_districts() -> List[str]:
    """返回行政区字典"""
    return ZJK_DISTRICTS


# ==================== 一户一码 ====================

def generate_house_code(community: str, building: str, unit: str, room_no: str) -> str:
    raw = f"{community.strip()}#{building.strip()}#{unit.strip()}#{room_no.strip()}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:16]


# ==================== 数据模型 ====================

class CreateListingRequest(BaseModel):
    """创建房源请求"""
    district: str = Field(..., min_length=1, max_length=20, description="行政区")
    community: str = Field(..., min_length=1, max_length=50, description="小区名")
    building: str = Field(..., min_length=1, max_length=20, description="楼号")
    unit: str = Field(..., min_length=1, max_length=10, description="单元号")
    room_no: str = Field(..., min_length=1, max_length=10, description="门牌号")
    area_sqm: float = Field(..., gt=0, le=2000, description="建筑面积(㎡)")
    rooms: int = Field(..., ge=0, le=20, description="卧室数")
    halls: int = Field(..., ge=0, le=10, description="客厅数")
    bathrooms: int = Field(..., ge=0, le=10, description="卫生间数")
    floor: int = Field(..., ge=-5, le=200, description="所在楼层")
    total_floor: int = Field(..., ge=1, le=200, description="总楼层")
    orientation: str = Field(..., max_length=20, description="朝向")
    price_wan: float = Field(..., gt=0, description="报价(万元)")
    remarks: Optional[str] = Field(None, max_length=500, description="备注")


class CreateListingResponse(BaseModel):
    success: bool
    listing_id: str
    house_code: str
    message: str


# ==================== 业务函数 ====================

def _layout_text(rooms: int, halls: int, bathrooms: int) -> str:
    """把 3,2,2 组成 '3室2厅2卫'"""
    return f"{rooms}室{halls}厅{bathrooms}卫"


def create_listing(req: CreateListingRequest, agent: dict) -> dict:
    from fastapi import HTTPException

    # 1. 一户一码
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
        "district": req.district.strip(),
        "community": req.community.strip(),
        "building": req.building.strip(),
        "unit": req.unit.strip(),
        "room_no": req.room_no.strip(),
        "area_sqm": req.area_sqm,
        "rooms": req.rooms,
        "halls": req.halls,
        "bathrooms": req.bathrooms,
        "layout": _layout_text(req.rooms, req.halls, req.bathrooms),
        "floor": req.floor,
        "total_floor": req.total_floor,
        "orientation": req.orientation,
        "price_wan": req.price_wan,
        "remarks": req.remarks or "",
        "status": "on_sale",
        "owner_agent_id": agent["_id"],
        "owner_agent_name": agent["name"],
        "owner_agent_phone": agent["phone"],
        "created_at": now,
        "updated_at": now,
    }

    result = listings_collection.insert_one(doc)
    return {
        "listing_id": str(result.inserted_id),
        "house_code": house_code,
    }


def ensure_indexes():
    """建立索引"""
    listings_collection.create_index("house_code", unique=True)
    listings_collection.create_index("owner_agent_id")
    listings_collection.create_index("community")
    listings_collection.create_index("district")  # V2 新增


# ==================== 查询函数 ====================

def list_my_listings(agent_id: ObjectId, skip: int = 0, limit: int = 20) -> list:
    cursor = (
        listings_collection.find({"owner_agent_id": agent_id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    return [_format_listing(doc) for doc in cursor]


def count_my_listings(agent_id: ObjectId) -> int:
    return listings_collection.count_documents({"owner_agent_id": agent_id})


def list_shared_listings(
    current_agent_id: ObjectId, skip: int = 0, limit: int = 20
) -> list:
    cursor = (
        listings_collection.find({
            "status": "on_sale",
            "owner_agent_id": {"$ne": current_agent_id},
        })
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    return [_format_listing_anonymous(doc) for doc in cursor]


def count_shared_listings(current_agent_id: ObjectId) -> int:
    return listings_collection.count_documents({
        "status": "on_sale",
        "owner_agent_id": {"$ne": current_agent_id},
    })


def get_listing_by_id(listing_id: str) -> dict | None:
    try:
        doc = listings_collection.find_one({"_id": ObjectId(listing_id)})
    except Exception:
        return None
    if not doc:
        return None
    return _format_listing(doc)


# ==================== 更新 / 下架 / 重新上架 ====================

def update_listing(
    listing_id: str,
    update_fields: dict,
    current_agent_id: ObjectId,
) -> dict:
    from fastapi import HTTPException

    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权修改他人的房源")
    if doc.get("status") == "offline":
        raise HTTPException(status_code=400, detail="已下架的房源不能编辑")

    # V2 新增:允许编辑 rooms/halls/bathrooms,同步更新 layout 字符串
    allowed = {
        "rooms", "halls", "bathrooms",
        "floor", "total_floor", "orientation",
        "price_wan", "remarks",
    }
    clean_fields = {
        k: v for k, v in update_fields.items()
        if k in allowed and v is not None
    }
    if not clean_fields:
        raise HTTPException(status_code=400, detail="没有有效的更新字段")

    # 如果改了户型数字,要同步 layout 字符串
    if any(k in clean_fields for k in ("rooms", "halls", "bathrooms")):
        rooms = clean_fields.get("rooms", doc.get("rooms", 0))
        halls = clean_fields.get("halls", doc.get("halls", 0))
        bathrooms = clean_fields.get("bathrooms", doc.get("bathrooms", 0))
        clean_fields["layout"] = _layout_text(rooms, halls, bathrooms)

    clean_fields["updated_at"] = datetime.now()

    listings_collection.update_one({"_id": oid}, {"$set": clean_fields})
    new_doc = listings_collection.find_one({"_id": oid})
    return _format_listing(new_doc)


def offline_listing(listing_id: str, current_agent_id: ObjectId) -> dict:
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


def reactivate_listing(listing_id: str, current_agent_id: ObjectId) -> dict:
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


# ==================== 格式化器 ====================

def _format_listing(doc: dict) -> dict:
    """完整版 - 含录入人信息,用于"我的房源"和详情页"""
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "district": doc.get("district", ""),
        "community": doc["community"],
        "building": doc["building"],
        "unit": doc["unit"],
        "room_no": doc["room_no"],
        "area_sqm": doc["area_sqm"],
        "rooms": doc.get("rooms", 0),
        "halls": doc.get("halls", 0),
        "bathrooms": doc.get("bathrooms", 0),
        "layout": doc.get("layout", ""),
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


def _format_listing_anonymous(doc: dict) -> dict:
    """匿名版 - 共享库用"""
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "district": doc.get("district", ""),
        "community": doc["community"],
        "building": doc["building"],
        "unit": doc["unit"],
        "room_no": doc["room_no"],
        "area_sqm": doc["area_sqm"],
        "rooms": doc.get("rooms", 0),
        "halls": doc.get("halls", 0),
        "bathrooms": doc.get("bathrooms", 0),
        "layout": doc.get("layout", ""),
        "floor": doc["floor"],
        "total_floor": doc["total_floor"],
        "orientation": doc["orientation"],
        "price_wan": doc["price_wan"],
        "remarks": doc.get("remarks", ""),
        "status": doc.get("status", "on_sale"),
        "created_at": doc["created_at"].isoformat(),
    }