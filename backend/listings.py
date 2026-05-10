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
from pydantic import BaseModel, Field, field_validator
from const.sale_points import validate_sale_points
from bson import ObjectId
from fastapi import HTTPException
from database import db, client
from services.listing_filter import batch_fetch_communities_by_name, passes_dict_filters
from services.listing_enrich import enrich_from_dictionary, enrich_community_from_dict

listings_collection = db["listings"]
showing_requests_collection = db["showing_requests"]

MAX_PHOTOS = 6

# V2.2 #2: 删 halls, 物理字段 6→5
DICT_PHYSICAL_FIELDS = ("area_sqm", "floor", "total_floor", "rooms", "bathrooms")
# V2.2 #2: 辞典可选 claim 字段(objective_features + decoration + house_structure)
DICT_OPTIONAL_CLAIM_FIELDS = ("objective_features", "decoration", "house_structure")


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
    orientation: str = Field(..., max_length=20)
    price_wan: float = Field(..., gt=0)
    bonus_yuan: Optional[int] = Field(
        0, ge=0, le=500_000, description="合作奖金(元),0=无奖金"
    )
    cover_thumbnail: Optional[str] = Field(None, description="封面缩略图 base64")
    photos: Optional[List[PhotoItem]] = Field(default=None, description="完整照片列表")
    # V2.2 #1: 4 新字段(remark 拆为 public/agent,showing_instructions,sale_points)
    sale_points: Optional[List[str]] = Field(default=None, description="卖点标签(上限25:21预设+4自定义)")
    public_remarks: Optional[str] = Field(None, max_length=2000, description="公开备注(所有人可见)")
    agent_remarks: Optional[str] = Field(None, max_length=1000, description="经纪人备注(仅协作中 BA+LA 可见)")
    showing_instructions: Optional[str] = Field(None, max_length=500, description="看房指引(仅协作中 BA+LA 可见)")

    @field_validator("sale_points")
    @classmethod
    def validate_tags(cls, v):
        if v is not None:
            validate_sale_points(v)
        return v


class PostListingRequest(CreateListingRequest):
    """LA 挂牌请求,继承 CreateListingRequest + 6 物理字段 + 辞典身份字段(调辞典后不写本地)"""
    # V8.7 坑 38: city_id/district_id Optional 但后端会自动 lookup(从 req.district 字符串),
    # 未来 Flutter 加城市选择器后再改必填
    city_id: Optional[str] = Field(None, description="城市 ID(调辞典用,可选)")
    district_id: Optional[str] = Field(None, description="区县 ID(调辞典用,可选)")
    area_sqm: float = Field(..., gt=0, le=2000, description="面积(调辞典 claim,不持久化到 listing)")
    floor: int = Field(..., ge=-5, le=200, description="楼层(调辞典 claim,不持久化到 listing)")
    total_floor: int = Field(..., ge=1, le=200, description="总楼层(调辞典 claim,不持久化到 listing)")
    rooms: int = Field(..., ge=0, le=20, description="室(调辞典 claim,不持久化到 listing)")
    bathrooms: int = Field(..., ge=0, le=10, description="卫(调辞典 claim,不持久化到 listing)")
    # V2.2 #1: 辞典可选 claim(与物理字段同流程 always-accept)
    objective_features: Optional[List[str]] = Field(None, description="客观特征(调辞典 claim,可选)")
    decoration: Optional[str] = Field(None, description="装修情况(调辞典 claim,可选)")
    # V2.2 #2: 户型结构(调辞典 claim,可选)
    house_structure: Optional[str] = Field(None, description="户型结构(平层/复式/Loft/跃层/错层/跃复一体)")


def _extract_physical_attrs(req) -> dict:
    """从请求中提取物理字段 + V2.2 可选客观字段,用于调辞典 submit_claim"""
    attrs = {field: getattr(req, field) for field in DICT_PHYSICAL_FIELDS}
    for field in DICT_OPTIONAL_CLAIM_FIELDS:
        v = getattr(req, field, None)
        if v is not None:
            attrs[field] = v
    return attrs


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

def _layout_text(rooms: int, bathrooms: int) -> str:
    """V2.2 #2: 删 halls, layout 仅 rooms + bathrooms。"""
    return f"{rooms}室{bathrooms}卫"


def create_listing(req, physical_attrs: dict, agent: dict) -> dict:
    """LA 挂牌。physical_attrs = {area_sqm, floor, total_floor, rooms, halls, bathrooms}。

    V2.1 #15: 先调辞典 identify + claim,成功后写本地 listing(仅营销字段 +
    property_code)。辞典不可达 → 503; claim 冲突 → 409 + diff。
    """
    from dictionary_client import DictionaryClient, DictionaryUnavailableError, DictionaryForbiddenError

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

    # ── 1. 调辞典 identify + claim ──
    d = DictionaryClient()
    community_id_str = str(community_oid) if community_oid else None

    # V8.7 坑 38: city_id/district_id 自动 lookup
    # 张家口是 V2.1 唯一城市,district 字符串匹配辞典 districts.name
    city_id = getattr(req, "city_id", None) or None
    district_id = getattr(req, "district_id", None) or None

    if not city_id or not district_id:
        # 从 property_dict 数据库直接查(同 Mongo 实例,不同 database)
        dict_db = client.get_database("property_dict")
        if not city_id:
            zjk = dict_db["cities"].find_one({"name": "张家口"})
            if zjk:
                city_id = str(zjk["_id"])
        if not district_id:
            district_name = getattr(req, "district", "")
            if district_name:
                dist = dict_db["districts"].find_one({"name": district_name})
                if dist:
                    district_id = str(dist["_id"])

        if not city_id or not district_id:
            raise HTTPException(
                status_code=400,
                detail="缺少 city_id/district_id,自动 lookup 也失败。请确认 district 字段与辞典 districts.name 一致"
            )

    # V8.7 坑 38: MLS community_id 是 mls.communities 集合的 ObjectId,
    # 不是辞典 communities 的 ObjectId。通过 community name 调辞典 identify 拿到辞典侧 community_id
    community_name = getattr(req, "community", "").strip()
    try:
        dict_community = d.identify_community(city_id, district_id, community_name)
        dict_community_id = dict_community["_id"]
    except DictionaryNotFoundError:
        dict_community = d.identify_community(city_id, district_id, community_name)
        dict_community_id = dict_community["_id"]

    try:
        prop = d.identify_property(
            city_id, district_id, dict_community_id,
            req.building.strip(), req.unit.strip(), req.room_no.strip(),
        )
        property_code = prop["property_code"]
        d.submit_claim(property_code, physical_attrs, str(agent["_id"]))
    except DictionaryUnavailableError as e:
        raise HTTPException(status_code=503, detail=f"辞典服务不可达: {e}")
    except DictionaryForbiddenError as e:
        raise HTTPException(status_code=503, detail=f"辞典鉴权失败(配置问题): {e}")

    # ── 2. 派生 layout ──
    layout = _layout_text(
        physical_attrs.get("rooms", 0),
        physical_attrs.get("bathrooms", 0),
    )

    # ── 3. 写本地 listing ──
    now = datetime.now()
    doc = {
        "house_code": house_code,
        "district": req.district.strip(),
        "community": req.community.strip(),
        "community_id": community_oid,
        "building": req.building.strip(),
        "unit": req.unit.strip(),
        "room_no": req.room_no.strip(),
        "property_code": property_code,
        "layout": layout,
        "orientation": req.orientation,
        "price_wan": req.price_wan,
        "bonus_yuan": int(req.bonus_yuan or 0),
        "status": "on_sale",
        "cover_thumbnail": req.cover_thumbnail,
        "photos": photos_list,
        "photo_count": len(photos_list),
        # V2.2 #1: remark 拆为 agent_remarks(私有) + public_remarks(公开)
        "agent_remarks": req.agent_remarks or "",
        "public_remarks": req.public_remarks or "",
        "showing_instructions": req.showing_instructions or "",
        "sale_points": req.sale_points or [],
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
    docs = list(cursor)
    props_map = _batch_fetch_props(docs)
    results = [_format_listing_lite(doc) for doc in docs]
    for r in results:
        _enrich_physical_fields(r, props_map)
    return results


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
    # V2.2 #1: 5 类新筛选
    sale_points: Optional[list[str]] = None,
    objective_features: Optional[list[str]] = None,
    decoration: Optional[str] = None,
    heating_type: Optional[str] = None,
    bld_year_min: Optional[int] = None,
    bld_year_max: Optional[int] = None,
    community_id: Optional[str] = None,
    # V2.2 #2: 朝向 + 户型结构
    orientation: Optional[str] = None,
    house_structure: Optional[str] = None,
    sort: Optional[str] = None,
) -> tuple[list, int]:
    """共享库:所有交易状态的房源都展示(V10:sold 也公开展示成交价)

    V2.2 #1: 5 类筛选 — sale_points(本地 $all) + 4 类辞典过滤(batch 拉取后聚合)。
    community_id: 按 MLS 侧小区 ObjectId 过滤(小区主页"在售房源"用)。
    V2.2 #2: 加 orientation(本地) + house_structure(辞典) 筛选。

    返 (items, total):items 是分页后结果,total 是筛选后总数。
    """
    query = {
        "status": {"$in": SHARED_VISIBLE_STATUSES},
        "owner_agent_id": {"$ne": current_agent_id},
    }
    if new_today:
        today_start = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0)
        query["created_at"] = {"$gte": today_start}

    # ── Step A: MLS 本地过滤 ──
    if sale_points:
        query["sale_points"] = {"$all": sale_points}
    if community_id:
        try:
            query["community_id"] = ObjectId(community_id)
        except Exception:
            pass
    if orientation:
        query["orientation"] = orientation

    needs_dict_filter = bool(objective_features or decoration or heating_type
                              or bld_year_min is not None or bld_year_max is not None
                              or house_structure)

    if needs_dict_filter:
        # 需要后端聚合时,先全量拉取(无 skip/limit),过滤后再分页
        docs = list(listings_collection.find(query).sort("created_at", -1))
    else:
        if sort and sort != "default":
            docs = list(listings_collection.find(query))
            _sort_docs(docs, sort)
            docs = docs[skip:skip + limit]
        else:
            docs = list(
                listings_collection.find(query)
                .sort("created_at", -1)
                .skip(skip)
                .limit(limit)
            )

    if not docs:
        return [], 0

    # Day 16:批量查 my_request_status
    listing_oids = [d["_id"] for d in docs]
    my_status_map = _build_my_request_status_map(listing_oids, current_agent_id)

    props_map = _batch_fetch_props(docs)

    # ── Step B: 拉辞典社区数据(按名称) ──
    community_by_name = {}
    if needs_dict_filter:
        community_by_name = batch_fetch_communities_by_name(docs)

    # ── Step C: 后端聚合过滤 ──
    if needs_dict_filter:
        filtered_docs = []
        for doc in docs:
            if not passes_dict_filters(
                doc, props_map, community_by_name,
                objective_features, decoration, heating_type,
                bld_year_min, bld_year_max, house_structure,
            ):
                continue
            filtered_docs.append(doc)
        _sort_docs(filtered_docs, sort)
        total = len(filtered_docs)
        docs = filtered_docs[skip:skip + limit]
    else:
        total = count_shared_listings(current_agent_id, new_today=new_today, sale_points=sale_points, orientation=orientation)

    results = [
        _format_listing_anonymous_lite(
            doc,
            my_request_status=my_status_map.get(str(doc["_id"])),
        )
        for doc in docs
    ]
    for r in results:
        _enrich_physical_fields(r, props_map)
    return results, total


def count_shared_listings(
    current_agent_id: ObjectId, new_today: bool = False,
    sale_points: Optional[list[str]] = None,
    community_id: Optional[str] = None,
    orientation: Optional[str] = None,
) -> int:
    query = {
        "status": {"$in": SHARED_VISIBLE_STATUSES},
        "owner_agent_id": {"$ne": current_agent_id},
    }
    if new_today:
        today_start = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0)
        query["created_at"] = {"$gte": today_start}
    if sale_points:
        query["sale_points"] = {"$all": sale_points}
    if community_id:
        try:
            query["community_id"] = ObjectId(community_id)
        except Exception:
            pass
    if orientation:
        query["orientation"] = orientation
    return listings_collection.count_documents(query)


def _sort_docs(docs: list, sort: Optional[str]) -> None:
    """服务端排序。default/latest 不排序(MongoDB 已按 created_at desc)。"""
    if not sort or sort in ("default", "latest"):
        docs.sort(key=lambda d: d.get("created_at") or "", reverse=True)
    elif sort == "price_asc":
        docs.sort(key=lambda d: d.get("price_wan", 0) or 0)
    elif sort == "price_desc":
        docs.sort(key=lambda d: d.get("price_wan", 0) or 0, reverse=True)
    elif sort == "unit_price_asc":
        def _unit_price(d):
            area = (d.get("area_sqm") or 0)
            return (d.get("price_wan", 0) or 0) / area if area > 0 else 0
        docs.sort(key=_unit_price)
    elif sort == "area_desc":
        docs.sort(key=lambda d: d.get("area_sqm") or 0, reverse=True)


def get_listing_by_id(listing_id: str, viewer_id=None) -> dict | None:
    try:
        doc = listings_collection.find_one({"_id": ObjectId(listing_id)})
    except Exception:
        return None
    if not doc:
        return None
    result = _format_listing_full(doc)
    # V2.1 #15: 尝试从辞典侧补物理字段,失败时保持 None 占位(graceful degrade)
    enrich_from_dictionary(result, doc, viewer_id)
    # V2.2 #1: 从 property_dict 补社区特征字段
    enrich_community_from_dict(result, doc)
    # V2.2 #1: 权限分层 — 非协作方隐藏 agent_remarks / showing_instructions / LA 手机号
    from utils.collaboration_status import is_collaboration_unlocked
    if not is_collaboration_unlocked(viewer_id, listing_id):
        result["agent_remarks"] = ""
        result["showing_instructions"] = ""
        result["owner_agent_phone"] = ""
    return result


# ==================== V2.2 #3: LA 视角带看汇总 ====================

_SR_STATUS_LABEL = {
    "pending": "申请中",
    "approved": "已通过",
    "showing_done": "已带看",
    "transaction_initiated": "已发起成交",
    "transaction_confirmed": "已成交",
    "rejected": "已拒绝",
    "canceled": "已取消",
}

_PHONE_HIDDEN_STATUSES = {"pending", "rejected", "canceled"}


def get_showings_summary(listing_id: str, viewer_id) -> list[dict]:
    """LA 查看自己房源的所有带看记录。仅 owner 可调用。"""
    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if str(doc["owner_agent_id"]) != str(viewer_id):
        raise HTTPException(status_code=403, detail="Not the owner of this listing")

    # 查该 listing 的所有 showing_requests
    srs = list(
        db["showing_requests"]
        .find({"listing_id": oid})
        .sort("created_at", -1)
    )

    if not srs:
        return []

    # 批量查 showings
    sr_ids = [sr["_id"] for sr in srs]
    showings_by_sr = {}
    for s in db["showings"].find({"showing_request_id": {"$in": sr_ids}}).sort("created_at", -1):
        showings_by_sr.setdefault(s["showing_request_id"], []).append(s)

    # 批量查 transactions
    all_showing_ids = [s["_id"] for sl in showings_by_sr.values() for s in sl]
    tx_by_showing = {}
    if all_showing_ids:
        for t in db["transactions"].find({"showing_id": {"$in": all_showing_ids}}):
            tx_by_showing[t["showing_id"]] = t

    # 批量查 BA agent 信息
    ba_ids = list(set(sr["buyer_agent_id"] for sr in srs))
    ba_map = {}
    for a in db["agents"].find({"_id": {"$in": ba_ids}}):
        ba_map[a["_id"]] = a

    result = []
    for sr in srs:
        showings = showings_by_sr.get(sr["_id"], [])
        latest_showing = showings[0] if showings else None

        transaction = None
        for s in showings:
            t = tx_by_showing.get(s["_id"])
            if t:
                transaction = t
                break

        # 判 current_status
        req_status = sr.get("status")
        if req_status in ("rejected", "canceled"):
            current_status = req_status
        elif transaction:
            tx_status = transaction.get("status")
            if tx_status == "confirmed":
                current_status = "transaction_confirmed"
            else:
                current_status = "transaction_initiated"
        elif latest_showing and latest_showing.get("status") == "confirmed":
            current_status = "showing_done"
        elif req_status in ("approved", "auto_approved"):
            current_status = "approved"
        else:
            current_status = "pending"

        # 计算 latest_event_at
        times = [sr.get("updated_at") or sr.get("created_at")]
        if showings:
            for s in showings:
                times.append(s.get("updated_at") or s.get("created_at"))
        if transaction:
            times.append(transaction.get("updated_at") or transaction.get("created_at"))
        latest_event = max(t for t in times if t is not None)

        # BA 信息
        ba = ba_map.get(sr["buyer_agent_id"], {})
        ba_phone = ba.get("phone") if current_status not in _PHONE_HIDDEN_STATUSES else None

        # 客户需求截断
        demand = sr.get("requirements", "") or ""
        if len(demand) > 60:
            demand = demand[:60]

        result.append({
            "showing_request_id": str(sr["_id"]),
            "ba_id": str(sr["buyer_agent_id"]),
            "ba_name": sr.get("buyer_agent_name", ba.get("name", "")),
            "ba_phone": ba_phone,
            "customer_name": f"{sr.get('customer_surname', '')}{'先生' if sr.get('customer_gender') == 'male' else '女士'}",
            "customer_demand": demand,
            "created_at": sr["created_at"].isoformat() if sr.get("created_at") else None,
            "latest_event_at": latest_event.isoformat() if latest_event else None,
            "current_status": current_status,
            "current_status_label": _SR_STATUS_LABEL.get(current_status, current_status),
        })

    result.sort(key=lambda x: x.get("latest_event_at") or "", reverse=True)
    return result


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

    # V2.1 #15: 物理字段(rooms/halls/bathrooms/floor/total_floor)已迁移到辞典
    allowed = {
        "orientation", "price_wan",
        "bonus_yuan",
        "cover_thumbnail", "photos",
        # V2.2 #1: remark 拆为 agent_remarks + public_remarks
        "public_remarks", "agent_remarks",
        "showing_instructions", "sale_points",
    }
    clean_fields = {
        k: v for k, v in update_fields.items()
        if k in allowed and v is not None
    }
    if not clean_fields:
        raise HTTPException(status_code=400, detail="没有有效的更新字段")

    if "sale_points" in clean_fields:
        validate_sale_points(clean_fields["sale_points"])

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


# ==================== V2.1 #15 sync-physical ====================

class SyncPhysicalBody(BaseModel):
    area_sqm: Optional[float] = Field(None, description="面积(㎡),不传则自动从权威值读")
    floor: Optional[int] = Field(None, description="所在楼层")
    total_floor: Optional[int] = Field(None, description="总楼层")
    rooms: Optional[int] = Field(None, description="室")
    bathrooms: Optional[int] = Field(None, description="卫")
    # V2.2 #1: 客观字段同步(辞典 always-accept)
    objective_features: Optional[list[str]] = Field(None, description="客观特征(辞典 claim,可选)")
    decoration: Optional[str] = Field(None, description="装修情况(辞典 claim,可选)")
    # V2.2 #2: 户型结构
    house_structure: Optional[str] = Field(None, description="户型结构(平层/复式/Loft/跃层/错层/跃复一体)")
    force: bool = Field(False, description="True=冲突仍接受,写 discrepancy 工单")


def sync_physical_to_dict(listing_id: str, body, viewer_id) -> dict:
    """LA 同步物理字段到辞典。

    - body 全 None → 自动从 authoritative_attrs 拉
    - body 有值 → 用 LA 填的值调 submit_claim
    - force=True → 冲突仍接受

    只允许 listing.owner_agent_id 调用;需 listing.property_code 存在。
    """
    from dictionary_client import DictionaryClient, DictionaryUnavailableError, DictionaryNotFoundError

    try:
        oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    doc = listings_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    if str(doc.get("owner_agent_id")) != str(viewer_id):
        raise HTTPException(status_code=403, detail="只有房源归属人可以同步权威值")

    property_code = doc.get("property_code")
    if not property_code:
        raise HTTPException(status_code=400, detail="该房源未关联辞典 property,无法同步")

    # Determine attrs: body values first, fallback to authoritative_attrs
    has_body = any(
        getattr(body, f, None) is not None
        for f in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS
    )
    attrs = {}

    if has_body:
        for f in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS:
            v = getattr(body, f, None)
            if v is not None:
                attrs[f] = v
    else:
        try:
            prop = DictionaryClient().get_property(property_code)
        except DictionaryNotFoundError:
            raise HTTPException(status_code=500, detail="辞典 property 不存在(数据不一致)")
        except DictionaryUnavailableError as e:
            raise HTTPException(status_code=503, detail=f"辞典服务暂时不可达: {e}")

        authoritative = prop.get("authoritative_attrs", {}) or {}
        if not authoritative:
            raise HTTPException(status_code=400, detail="辞典 property 暂无权威值,无法同步")
        for field in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS:
            if field in authoritative and authoritative[field] is not None:
                attrs[field] = authoritative[field]

    if not attrs:
        raise HTTPException(status_code=400, detail="没有可同步的物理字段")

    try:
        result = DictionaryClient().submit_claim(
            code=property_code, attrs=attrs,
            agent_id=str(viewer_id), listing_id=str(listing_id),
        )
    except DictionaryUnavailableError as e:
        raise HTTPException(status_code=503, detail=f"辞典服务暂时不可达: {e}")

    # Return comparison_results for 黄条
    comparison = result.get("comparison_results", [])

    return {
        "synced_fields": list(attrs.keys()),
        "synced_values": attrs,
        "listing_id": listing_id,
        "comparison_results": comparison,
    }


# ==================== V2.1 #15 batch 富化 ====================

def _batch_fetch_props(docs: list) -> dict:
    """批量调辞典 batch_get_properties,返回 {code: prop_dict_or_null}。失败返 {}。"""
    codes = [d.get("property_code") for d in docs if d.get("property_code")]
    if not codes:
        return {}
    try:
        from dictionary_client import DictionaryClient
        return DictionaryClient().batch_get_properties(codes)
    except Exception:
        return {}


def _enrich_physical_fields(result: dict, props_map: dict) -> None:
    """用 batch 返回的 property 数据替换 result 中的物理字段 null 占位。"""
    code = result.get("property_code")
    if not code:
        return
    prop = props_map.get(code)
    if not prop:
        return
    # authoritative_attrs 优先
    auth = prop.get("authoritative_attrs", {}) or {}
    for field in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS:
        val = auth.get(field)
        if val is not None:
            result[field] = val
    # attribute_claims_latest 兜底
    claims = prop.get("attribute_claims_latest", {}) or {}
    for field in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS:
        if result.get(field) is None and field in claims:
            result[field] = claims[field]


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
        "property_code": doc.get("property_code"),
        # V2.1 段 7.2 临时占位,段 7.5 删除
        "area_sqm": None,
        "floor": None,
        "total_floor": None,
        "rooms": None,
        "halls": None,
        "bathrooms": None,
        "layout": doc.get("layout", ""),
        "orientation": doc["orientation"],
        "price_wan": doc["price_wan"],
        "bonus_yuan": int(doc.get("bonus_yuan", 0) or 0),
        "status": doc.get("status", "on_sale"),
        "status_label": STATUS_LABELS.get(doc.get("status", "on_sale"), doc.get("status", "")),
        "cover_thumbnail": doc.get("cover_thumbnail"),
        "photos": doc.get("photos", []),
        "photo_count": doc.get("photo_count", 0),
        # V2.2 #1: remark 拆为 public_remarks + agent_remarks
        "agent_remarks": doc.get("agent_remarks", ""),
        "public_remarks": doc.get("public_remarks", ""),
        "showing_instructions": doc.get("showing_instructions", ""),
        "sale_points": doc.get("sale_points", []),
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
        "property_code": doc.get("property_code"),
        # V2.1 段 7.2 临时占位,段 7.5 删除
        "area_sqm": None,
        "floor": None,
        "total_floor": None,
        "rooms": None,
        "halls": None,
        "bathrooms": None,
        "layout": doc.get("layout", ""),
        "orientation": doc["orientation"],
        "price_wan": doc["price_wan"],
        "public_remarks": doc.get("public_remarks", ""),
        "sale_points": doc.get("sale_points", []),
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
        "property_code": doc.get("property_code"),
        # V2.1 段 7.2 临时占位,段 7.5 删除
        "area_sqm": None,
        "floor": None,
        "total_floor": None,
        "rooms": None,
        "halls": None,
        "bathrooms": None,
        "layout": doc.get("layout", ""),
        "orientation": doc["orientation"],
        "price_wan": doc["price_wan"],
        "public_remarks": doc.get("public_remarks", ""),
        "sale_points": doc.get("sale_points", []),
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