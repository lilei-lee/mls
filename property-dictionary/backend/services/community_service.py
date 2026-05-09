"""community 命中/创建业务逻辑"""
from datetime import datetime
from typing import Optional
from bson import ObjectId
import hmac, hashlib, base64

from database import db
from config import DICT_SECRET_KEY
from models.community import communities_collection
from services.exceptions import (
    CommunityNotFound, DistrictNotFound, CityNotFound, InvalidIdentifier,
)


def _to_oid(value, error_msg: str = "Invalid identifier") -> ObjectId:
    if isinstance(value, ObjectId):
        return value
    try:
        return ObjectId(str(value))
    except Exception:
        raise InvalidIdentifier(error_msg)


def _generate_community_code(city_id, district_id, name: str) -> str:
    parts = [str(city_id), str(district_id), name.strip()]
    message = "|".join(parts).encode("utf-8")
    secret = DICT_SECRET_KEY.encode("utf-8")
    digest = hmac.new(secret, message, hashlib.sha256).digest()
    code_b32 = base64.b32encode(digest[:8]).decode("ascii")
    return code_b32[:12]


def get_or_create_community(city_id, district_id, name: str) -> dict:
    city_oid = _to_oid(city_id, "Invalid city_id")
    district_oid = _to_oid(district_id, "Invalid district_id")
    name = name.strip()
    if not name:
        raise InvalidIdentifier("Community name is empty")

    city = db["cities"].find_one({"_id": city_oid})
    if not city:
        raise CityNotFound(f"City {city_oid} not found")
    district = db["districts"].find_one({"_id": district_oid, "city_id": city_oid})
    if not district:
        raise DistrictNotFound(f"District {district_oid} not found or not in city {city_oid}")

    existing = communities_collection.find_one({
        "city_id": city_oid, "district_id": district_oid, "name": name,
    })
    if existing:
        return existing

    code = _generate_community_code(city_oid, district_oid, name)
    now = datetime.now()
    doc = {
        "community_code": code, "city_id": city_oid, "district_id": district_oid,
        "name": name, "aliases": [],
        # 基础
        "built_year": None, "bld_year_start": None, "bld_year_end": None,
        "total_buildings": None, "total_units": None,
        # 规划
        "plot_ratio": None, "green_ratio": None,
        # 物业
        "property_type": None, "developer": None, "property_management": None,
        "property_company": None, "property_fee_yuan": None, "building_types": None,
        # 供暖
        "heating_type": None,
        # 教育
        "primary_school": None, "middle_school": None,
        # 交通
        "nearest_highway": None, "nearest_train_station": None,
        # 生活
        "nearby_market": None, "nearby_hospital": None,
        # 车位
        "parking_total": None, "parking_ratio": None,
        # 既有
        "facilities": {"schools": [], "transportation": [], "commercial": []},
        "standard_assets": {"aerial_photo_url": None, "entrance_photo_url": None, "main_layouts": []},
        "derived_stats": {"avg_price_wan": None, "transaction_count_30d": None, "on_sale_count": None, "last_updated": None},
        "authoritative_attrs": {},
        "created_at": now, "updated_at": now,
    }
    result = communities_collection.insert_one(doc)
    doc["_id"] = result.inserted_id
    return doc


def get_community_by_code(code: str) -> dict:
    doc = communities_collection.find_one({"community_code": code})
    if not doc:
        raise CommunityNotFound(f"Community code {code} not found")
    return doc


def get_community_by_id(_id) -> dict:
    oid = _to_oid(_id, "Invalid community id")
    doc = communities_collection.find_one({"_id": oid})
    if not doc:
        raise CommunityNotFound(f"Community {oid} not found")
    return doc


def list_communities_by_city(city_id, name_keyword: Optional[str] = None, limit: int = 50) -> list[dict]:
    city_oid = _to_oid(city_id, "Invalid city_id")
    query: dict = {"city_id": city_oid}
    if name_keyword:
        query["name"] = {"$regex": name_keyword.strip(), "$options": "i"}
    return list(communities_collection.find(query).sort("name", 1).limit(limit))
