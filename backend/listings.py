"""
MLS 模块二 - 房源管理
作者:磊

V5 升级(模块五):
- 新增状态:deposit_paid / transaction_ongoing / sold
- 状态流转函数(在售 ↔ 定金已付 ↔ 成交进行中 → 已售)
- 已售自动触发,LA 不能手动
- 共享库展示规则:on_sale/deposit_paid/transaction_ongoing/sold 都展示
  (仅 on_sale 能被申请带客,deposit_paid 种子期也放开以兼容 backup,
   transaction_ongoing/sold 不接带客)

Day 16 增量:
- list_shared_listings 在共享库每条 listing 上挂 my_request_status,
  防止 BA 重复对同一房发起申请
"""
import hashlib
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field
from bson import ObjectId
from fastapi import HTTPException
from database import db

listings_collection = db["listings"]
showing_requests_collection = db["showing_requests"]

MAX_PHOTOS = 6


# ==================== 张家口行政区字典 ====================

ZJK_DISTRICTS = [
    "桥东区", "桥西区", "宣化区", "下花园区",
    "万全区", "崇礼区", "怀来县", "涿鹿县", "其他",
]


def get_districts() -> List[str]:
    return ZJK_DISTRICTS


# ==================== 一户一码 ====================

def generate_house_code(community: str, building: str, unit: str, room_no: str) -> str:
    raw = f"{community.strip()}#{building.strip()}#{unit.strip()}#{room_no.strip()}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:16]


# ==================== 状态枚举 ====================

ALL_STATUSES = [
    "on_sale",              # 在售
    "deposit_paid",         # 定金已付
    "transaction_ongoing",  # 成交进行中
    "sold",                 # 已售(不可手动)
    "offline",              # 已下架(保留原逻辑)
]

# 共享库可见的状态(V10 业务设计)
SHARED_VISIBLE_STATUSES = ["on_sale", "deposit_paid", "transaction_ongoing", "sold"]

# 可被申请带客的状态(注:带客前置校验在 showing_requests.py 做,此处只列表)
BOOKABLE_STATUSES = ["on_sale", "deposit_paid"]

STATUS_LABELS = {
    "on_sale": "在售",
    "deposit_paid": "定金已付",
    "transaction_ongoing": "成交进行中",
    "sold": "已成交",
    "offline": "已下架",
}


# ==================== 数据模型 ====================

class PhotoItem(BaseModel):
    data: str = Field(..., description="base64 数据(含 data:image/jpeg;base64, 前缀)")
    width: Optional[int] = None
    height: Optional[int] = None
    size_kb: Optional[int] = None


class CreateListingRequest(BaseModel):
    district: str = Field(..., min_length=1, max_length=20)
    community: str = Field(..., min_length=1, max_length=50)
    community_id: Optional[str] = Field(None, description="小区ID(可选)")
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
    bonus_yuan: Optional[int] = Field(
        0, ge=0, le=500_000, description="合作奖金(元),0=无奖金"
    )
    cover_thumbnail: Optional[str] = Field(None, description="封面缩略图 base64")
    photos: Optional[List[PhotoItem]] = Field(default=None, description="完整照片列表")


class CreateListingResponse(BaseModel):
    success: bool
    listing_id: str
    house_code: str
    message: str


# ==================== 状态流转模型 ====================

class MarkDepositPaidBody(BaseModel):
    """标记定金已付(MVP 不强制凭证,预留字段)"""
    deposit_amount_yuan: Optional[int] = Field(None, ge=0, description="定金金额(元,仅自己可见)")
    deposit_proof_url: Optional[str] = Field(None, description="定金凭证(技术债:MVP 暂不用)")
    note: Optional[str] = Field(None, max_length=100)


class MarkTransactionOngoingBody(BaseModel):
    """标记成交进行中(可从 on_sale 或 deposit_paid 进入)"""
    contract_proof_url: Optional[str] = Field(None, description="购房合同凭证(技术债:MVP 暂不用)")
    note: Optional[str] = Field(None, max_length=100)


class RollbackStatusBody(BaseModel):
    """从 deposit_paid / transaction_ongoing 回退到 on_sale"""
    reason: str = Field(..., min_length=1, max_length=100)


# ==================== 业务函数 ====================

def _layout_text(rooms: int, halls: int, bathrooms: int) -> str:
    return f"{rooms}室{halls}厅{bathrooms}卫"


def create_listing(req: CreateListingRequest, agent: dict) -> dict:
    house_code = generate_house_code(
        req.community, req.building, req.unit, req.room_no
    )

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

    photos_list = [p.model_dump() for p in (req.photos or [])]
    if len(photos_list) > MAX_PHOTOS:
        raise HTTPException(
            status_code=400,
            detail=f"最多上传 {MAX_PHOTOS} 张照片"
        )

    community_oid = None
    if req.community_id:
        try:
            community_oid = ObjectId(req.community_id)
        except Exception:
            raise HTTPException(status_code=400, detail="无效的小区ID")

    now = datetime.now()
    doc = {
        "house_code": house_code,
        "district": req.district.strip(),
        "community": req.community.strip(),
        "community_id": community_oid,
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
        "bonus_yuan": int(req.bonus_yuan or 0),
        "status": "on_sale",
        "cover_thumbnail": req.cover_thumbnail,
        "photos": photos_list,
        "photo_count": len(photos_list),
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
    listings_collection.create_index("community_id")
    listings_collection.create_index("district")
    listings_collection.create_index("status")


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


# Day 16:状态优先级 —— approved 比 pending 更"硬"(approved 是终态在协作里活着)
_REQ_STATUS_PRIORITY = {
    "approved": 2,
    "auto_approved": 2,
    "pending": 1,
}


def _build_my_request_status_map(
    listing_oids: list,
    current_agent_id: ObjectId,
) -> dict:
    """Day 16:批量查"我对这些房子有什么活的申请"
    返回 {listing_id_str: status} 字典,只含 pending/approved 两种结果。
    """
    if not listing_oids:
        return {}

    cursor = showing_requests_collection.find(
        {
            "listing_id": {"$in": listing_oids},
            "buyer_agent_id": current_agent_id,
            "status": {"$in": ["pending", "approved", "auto_approved"]},
        },
        {"listing_id": 1, "status": 1, "created_at": 1},
    )

    result = {}
    for doc in cursor:
        lid = str(doc["listing_id"])
        new_status = doc["status"]
        new_priority = _REQ_STATUS_PRIORITY.get(new_status, 0)

        if lid not in result:
            result[lid] = new_status
        else:
            old_priority = _REQ_STATUS_PRIORITY.get(result[lid], 0)
            if new_priority > old_priority:
                result[lid] = new_status

    # 把 auto_approved 统一显示为 approved(前端只认两种)
    return {
        lid: "approved" if status == "auto_approved" else status
        for lid, status in result.items()
    }


def list_shared_listings(
    current_agent_id: ObjectId,
    skip: int = 0,
    limit: int = 20,
    new_today: bool = False,
) -> list:
    """共享库:所有交易状态的房源都展示(V10:sold 也公开展示成交价)

    new_today=True 时只返今日零点起新增的(配合工作台"今日新房源"卡片)。

    Day 16:每条 listing 加 my_request_status 字段,值为
    'pending' | 'approved' | None,前端用于显示"已申请"标签。
    """
    query = {
        "status": {"$in": SHARED_VISIBLE_STATUSES},
        "owner_agent_id": {"$ne": current_agent_id},
    }
    if new_today:
        today_start = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0)
        query["created_at"] = {"$gte": today_start}

    docs = list(
        listings_collection.find(query)
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )

    # Day 16:批量查 my_request_status
    listing_oids = [d["_id"] for d in docs]
    my_status_map = _build_my_request_status_map(listing_oids, current_agent_id)

    return [
        _format_listing_anonymous_lite(
            doc,
            my_request_status=my_status_map.get(str(doc["_id"])),
        )
        for doc in docs
    ]


def count_shared_listings(
    current_agent_id: ObjectId, new_today: bool = False
) -> int:
    query = {
        "status": {"$in": SHARED_VISIBLE_STATUSES},
        "owner_agent_id": {"$ne": current_agent_id},
    }
    if new_today:
        today_start = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0)
        query["created_at"] = {"$gte": today_start}
    return listings_collection.count_documents(query)


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
    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权修改他人的房源")

    # 已售/已下架的不能编辑
    if doc.get("status") in ("sold", "offline"):
        raise HTTPException(status_code=400,
                            detail=f"「{STATUS_LABELS.get(doc['status'])}」状态的房源不能编辑")

    allowed = {
        "rooms", "halls", "bathrooms",
        "floor", "total_floor", "orientation",
        "price_wan", "remarks",
        "bonus_yuan",
        "cover_thumbnail", "photos",
    }
    clean_fields = {
        k: v for k, v in update_fields.items()
        if k in allowed and v is not None
    }
    if not clean_fields:
        raise HTTPException(status_code=400, detail="没有有效的更新字段")

    if any(k in clean_fields for k in ("rooms", "halls", "bathrooms")):
        rooms = clean_fields.get("rooms", doc.get("rooms", 0))
        halls = clean_fields.get("halls", doc.get("halls", 0))
        bathrooms = clean_fields.get("bathrooms", doc.get("bathrooms", 0))
        clean_fields["layout"] = _layout_text(rooms, halls, bathrooms)

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

    # 只有 on_sale 可以直接下架,其他状态需要先回退(V10:简化为只允许 on_sale → offline)
    if doc.get("status") != "on_sale":
        raise HTTPException(
            status_code=400,
            detail=f"当前状态「{STATUS_LABELS.get(doc['status'])}」下不能直接下架,请先回退到「在售」"
        )

    listings_collection.update_one(
        {"_id": oid},
        {"$set": {"status": "offline", "updated_at": datetime.now()}},
    )
    new_doc = listings_collection.find_one({"_id": oid})
    return _format_listing_full(new_doc)


def reactivate_listing(listing_id: str, current_agent_id: ObjectId) -> dict:
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


# ==================== V5 新增:交易状态流转 ====================

def mark_listing_deposit_paid(
    listing_id: str,
    body: MarkDepositPaidBody,
    current_agent_id: ObjectId,
) -> dict:
    """标记定金已付:仅 on_sale → deposit_paid"""
    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人的房源")
    if doc.get("status") != "on_sale":
        raise HTTPException(
            status_code=400,
            detail=f"只能从「在售」状态切换(当前:{STATUS_LABELS.get(doc['status'])})"
        )

    update = {
        "status": "deposit_paid",
        "deposit_paid_at": datetime.now(),
        "updated_at": datetime.now(),
    }
    if body.deposit_amount_yuan is not None:
        update["deposit_amount_yuan"] = body.deposit_amount_yuan
    if body.deposit_proof_url:
        update["deposit_proof_url"] = body.deposit_proof_url
    if body.note:
        update["deposit_note"] = body.note.strip()

    listings_collection.update_one({"_id": oid}, {"$set": update})
    return _format_listing_full(listings_collection.find_one({"_id": oid}))


def mark_listing_transaction_ongoing(
    listing_id: str,
    body: MarkTransactionOngoingBody,
    current_agent_id: ObjectId,
) -> dict:
    """标记成交进行中:on_sale / deposit_paid → transaction_ongoing"""
    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人的房源")
    if doc.get("status") not in ("on_sale", "deposit_paid"):
        raise HTTPException(
            status_code=400,
            detail=f"只能从「在售」或「定金已付」切换(当前:{STATUS_LABELS.get(doc['status'])})"
        )

    update = {
        "status": "transaction_ongoing",
        "transaction_ongoing_at": datetime.now(),
        "updated_at": datetime.now(),
    }
    if body.contract_proof_url:
        update["contract_proof_url"] = body.contract_proof_url
    if body.note:
        update["transaction_note"] = body.note.strip()

    listings_collection.update_one({"_id": oid}, {"$set": update})
    return _format_listing_full(listings_collection.find_one({"_id": oid}))


def rollback_listing_to_on_sale(
    listing_id: str,
    body: RollbackStatusBody,
    current_agent_id: ObjectId,
) -> dict:
    """从 deposit_paid / transaction_ongoing 回退到 on_sale

    保护:该 listing 不能有 pending_la_confirm 的 transaction
    (放这里做循环 import 规避:函数里延迟 import)
    """
    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if doc["owner_agent_id"] != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人的房源")
    if doc.get("status") not in ("deposit_paid", "transaction_ongoing"):
        raise HTTPException(
            status_code=400,
            detail=f"只能从「定金已付」或「成交进行中」回退(当前:{STATUS_LABELS.get(doc['status'])})"
        )

    # 保护:有 pending_la_confirm 的 transaction 不能回退
    from transactions import has_active_transaction
    if has_active_transaction(oid):
        raise HTTPException(
            status_code=400,
            detail="该房源存在待确认的成交记录,请先由 BA 撤回或等待处理完成"
        )

    reason = body.reason.strip()
    listings_collection.update_one(
        {"_id": oid},
        {"$set": {
            "status": "on_sale",
            "updated_at": datetime.now(),
            "last_rollback_reason": reason,
            "last_rollback_at": datetime.now(),
        }}
    )
    return _format_listing_full(listings_collection.find_one({"_id": oid}))


# ==================== 格式化器 ====================

def _format_listing_full(doc: dict) -> dict:
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "district": doc.get("district", ""),
        "community": doc["community"],
        "community_id": str(doc["community_id"]) if doc.get("community_id") else None,
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
        "bonus_yuan": int(doc.get("bonus_yuan", 0) or 0),
        "status": doc.get("status", "on_sale"),
        "status_label": STATUS_LABELS.get(doc.get("status", "on_sale"), doc.get("status", "")),
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photos": doc.get("photos", []),
        "photo_count": doc.get("photo_count", 0),
        "owner_agent_id": str(doc["owner_agent_id"]),
        "owner_agent_name": doc["owner_agent_name"],
        "owner_agent_phone": doc.get("owner_agent_phone", ""),
        # V5:成交相关信息
        "sold_price_yuan": doc.get("sold_price_yuan"),
        "sold_date": doc["sold_date"].strftime("%Y-%m-%d")
        if doc.get("sold_date") else None,
        "sold_at": doc["sold_at"].isoformat() if doc.get("sold_at") else None,
        "created_at": doc["created_at"].isoformat(),
        "updated_at": doc["updated_at"].isoformat(),
    }


def _format_listing_lite(doc: dict) -> dict:
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "district": doc.get("district", ""),
        "community": doc["community"],
        "community_id": str(doc["community_id"]) if doc.get("community_id") else None,
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
        "status_label": STATUS_LABELS.get(doc.get("status", "on_sale"), doc.get("status", "")),
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photo_count": doc.get("photo_count", 0),
        "owner_agent_id": str(doc["owner_agent_id"]),
        "owner_agent_name": doc["owner_agent_name"],
        "owner_agent_phone": doc.get("owner_agent_phone", ""),
        "sold_price_yuan": doc.get("sold_price_yuan"),
        "sold_date": doc["sold_date"].strftime("%Y-%m-%d")
        if doc.get("sold_date") else None,
        "created_at": doc["created_at"].isoformat(),
        "updated_at": doc["updated_at"].isoformat(),
    }


def _format_listing_anonymous_lite(
    doc: dict,
    my_request_status: Optional[str] = None,
) -> dict:
    """
    Day 16:加 my_request_status 可选透出
    - 'pending' / 'approved' / None
    - 前端读这个字段决定共享库卡片右上角的"已申请"标签
    """
    return {
        "listing_id": str(doc["_id"]),
        "house_code": doc["house_code"],
        "district": doc.get("district", ""),
        "community": doc["community"],
        "community_id": str(doc["community_id"]) if doc.get("community_id") else None,
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
        "bonus_yuan": int(doc.get("bonus_yuan", 0) or 0),
        "status": doc.get("status", "on_sale"),
        "status_label": STATUS_LABELS.get(doc.get("status", "on_sale"), doc.get("status", "")),
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photo_count": doc.get("photo_count", 0),
        # sold 状态时公开成交价和日期
        "sold_price_yuan": doc.get("sold_price_yuan"),
        "sold_date": doc["sold_date"].strftime("%Y-%m-%d")
        if doc.get("sold_date") else None,
        # Day 16:我对这房的申请状态(防重复申请)
        "my_request_status": my_request_status,
        "created_at": doc["created_at"].isoformat(),
    }