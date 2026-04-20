"""
MLS 模块二 - 房源管理
作者:磊

V3 升级(段 8):
- 新增 cover_thumbnail 字段(封面缩略图,base64,约 40KB)
- 新增 photos 数组(完整大图,base64,最多 6 张)
- 列表接口只返回缩略图 + photo_count
- 详情接口返回完整 photos 数组
"""
import hashlib
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field
from bson import ObjectId
from database import db

# MongoDB 房源集合
listings_collection = db["listings"]

# 照片上限
MAX_PHOTOS = 6


# ==================== 张家口行政区字典 ====================

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
    return ZJK_DISTRICTS


# ==================== 一户一码 ====================

def generate_house_code(community: str, building: str, unit: str, room_no: str) -> str:
    raw = f"{community.strip()}#{building.strip()}#{unit.strip()}#{room_no.strip()}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:16]


# ==================== 数据模型 ====================

class PhotoItem(BaseModel):
    """单张照片"""
    data: str = Field(..., description="base64 数据(含 data:image/jpeg;base64, 前缀)")
    width: Optional[int] = None
    height: Optional[int] = None
    size_kb: Optional[int] = None


class CreateListingRequest(BaseModel):
    """创建房源请求"""
    district: str = Field(..., min_length=1, max_length=20)
    community: str = Field(..., min_length=1, max_length=50)
    building: str = Field(..., min_length=1, max_length=20)
    unit: str = Field(..., min_length=1, max_length=10)
    room_no: str = Field(..., min_length=1, max_length=10)
    area_sqm: float = Field(..., gt=0, le=2000)
    rooms: int = Field(..., ge=0, le=20)
    halls: int = Field(..., ge=0, le=10)
    bathrooms: int = Field(..., ge=0, le=10)
    floor: int = Field(..., ge=-5, le=200)
    total_floor: int = Field(..., ge=1, le=200)
    orientation: str = Field(..., max_length=20)
    price_wan: float = Field(..., gt=0)
    remarks: Optional[str] = Field(None, max_length=500)

    # 段 8 新增
    cover_thumbnail: Optional[str] = Field(None, description="封面缩略图 base64")
    photos: Optional[List[PhotoItem]] = Field(default=None, description="完整照片列表")


class CreateListingResponse(BaseModel):
    success: bool
    listing_id: str
    house_code: str
    message: str


# ==================== 业务函数 ====================

def _layout_text(rooms: int, halls: int, bathrooms: int) -> str:
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

    # 3. 照片数量校验
    photos_list = [p.model_dump() for p in (req.photos or [])]
    if len(photos_list) > MAX_PHOTOS:
        raise HTTPException(
            status_code=400,
            detail=f"最多上传 {MAX_PHOTOS} 张照片"
        )

    # 4. 组装文档
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
        # 段 8 新增
        "cover_thumbnail": req.cover_thumbnail,
        "photos": photos_list,
        "photo_count": len(photos_list),
        # 经纪人信息
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
    listings_collection.create_index("house_code", unique=True)
    listings_collection.create_index("owner_agent_id")
    listings_collection.create_index("community")
    listings_collection.create_index("district")


# ==================== 查询函数 ====================

def list_my_listings(agent_id: ObjectId, skip: int = 0, limit: int = 20) -> list:
    cursor = (
        listings_collection.find({"owner_agent_id": agent_id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    return [_format_listing_lite(doc) for doc in cursor]


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
    return [_format_listing_anonymous_lite(doc) for doc in cursor]


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
    return _format_listing_full(doc)


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

    allowed = {
        "rooms", "halls", "bathrooms",
        "floor", "total_floor", "orientation",
        "price_wan", "remarks",
        # 段 8:允许更新照片
        "cover_thumbnail", "photos",
    }
    clean_fields = {
        k: v for k, v in update_fields.items()
        if k in allowed and v is not None
    }
    if not clean_fields:
        raise HTTPException(status_code=400, detail="没有有效的更新字段")

    # 户型字段变更 → 同步 layout 字符串
    if any(k in clean_fields for k in ("rooms", "halls", "bathrooms")):
        rooms = clean_fields.get("rooms", doc.get("rooms", 0))
        halls = clean_fields.get("halls", doc.get("halls", 0))
        bathrooms = clean_fields.get("bathrooms", doc.get("bathrooms", 0))
        clean_fields["layout"] = _layout_text(rooms, halls, bathrooms)

    # 段 8:照片数组长度校验 + 同步 photo_count
    if "photos" in clean_fields:
        photos = clean_fields["photos"]
        if not isinstance(photos, list):
            raise HTTPException(status_code=400, detail="photos 字段必须是数组")
        if len(photos) > MAX_PHOTOS:
            raise HTTPException(
                status_code=400,
                detail=f"最多上传 {MAX_PHOTOS} 张照片"
            )
        clean_fields["photo_count"] = len(photos)

    clean_fields["updated_at"] = datetime.now()

    listings_collection.update_one({"_id": oid}, {"$set": clean_fields})
    new_doc = listings_collection.find_one({"_id": oid})
    return _format_listing_full(new_doc)


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
    return _format_listing_full(new_doc)


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
    return _format_listing_full(new_doc)


# ==================== 格式化器 ====================

def _format_listing_full(doc: dict) -> dict:
    """完整版 - 含 photos 数组,用于详情页"""
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
        # 段 8
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photos": doc.get("photos", []),
        "photo_count": doc.get("photo_count", 0),
        # 经纪人信息
        "owner_agent_id": str(doc["owner_agent_id"]),
        "owner_agent_name": doc["owner_agent_name"],
        "owner_agent_phone": doc.get("owner_agent_phone", ""),
        "created_at": doc["created_at"].isoformat(),
        "updated_at": doc["updated_at"].isoformat(),
    }


def _format_listing_lite(doc: dict) -> dict:
    """列表轻量版 - 只含 cover_thumbnail,不含 photos[]"""
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
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photo_count": doc.get("photo_count", 0),
        "owner_agent_id": str(doc["owner_agent_id"]),
        "owner_agent_name": doc["owner_agent_name"],
        "owner_agent_phone": doc.get("owner_agent_phone", ""),
        "created_at": doc["created_at"].isoformat(),
        "updated_at": doc["updated_at"].isoformat(),
    }


def _format_listing_anonymous_lite(doc: dict) -> dict:
    """共享库匿名轻量版 - 只含 cover_thumbnail,不含 photos[] 和录入人信息"""
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
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photo_count": doc.get("photo_count", 0),
        "created_at": doc["created_at"].isoformat(),
    }