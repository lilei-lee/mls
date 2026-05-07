"""property 命中/创建业务逻辑"""
from datetime import datetime
from typing import Optional
from bson import ObjectId

from database import db
from models.property import properties_collection
from services.coding import generate_property_code
from services.community_service import _to_oid
from services.exceptions import (
    CityNotFound, DistrictNotFound, CommunityNotFound,
    PropertyNotFound, InvalidIdentifier,
)


def get_or_create_property(
    city_id, district_id, community_id,
    building: str, unit: str, room_no: str,
) -> dict:
    city_oid = _to_oid(city_id, "Invalid city_id")
    district_oid = _to_oid(district_id, "Invalid district_id")
    community_oid = _to_oid(community_id, "Invalid community_id")
    building = (building or "").strip()
    unit = (unit or "").strip()
    room_no = (room_no or "").strip()
    if not (building and unit and room_no):
        raise InvalidIdentifier("building / unit / room_no must all be non-empty")

    city = db["cities"].find_one({"_id": city_oid})
    if not city:
        raise CityNotFound(f"City {city_oid} not found")
    district = db["districts"].find_one({"_id": district_oid, "city_id": city_oid})
    if not district:
        raise DistrictNotFound(f"District {district_oid} not found or not in city {city_oid}")
    community = db["communities"].find_one({
        "_id": community_oid, "city_id": city_oid, "district_id": district_oid,
    })
    if not community:
        raise CommunityNotFound(f"Community {community_oid} not found or not in city/district")

    code = generate_property_code(city_oid, district_oid, community_oid, building, unit, room_no)

    existing = properties_collection.find_one({"property_code": code})
    if existing:
        return existing

    now = datetime.now()
    doc = {
        "property_code": code,
        "city_id": city_oid, "district_id": district_oid, "community_id": community_oid,
        "building": building, "unit": unit, "room_no": room_no,
        "authoritative_attrs": {},
        "attribute_claims": [],
        "transaction_history": [], "listing_history": [],
        "standard_assets": {"floor_plan_url": None, "real_photos": []},
        "created_at": now, "updated_at": now,
    }
    try:
        result = properties_collection.insert_one(doc)
        doc["_id"] = result.inserted_id
        return doc
    except Exception:
        existing = properties_collection.find_one({"property_code": code})
        if existing:
            return existing
        raise


def get_property_by_code(code: str) -> dict:
    doc = properties_collection.find_one({"property_code": code})
    if not doc:
        raise PropertyNotFound(f"Property code {code} not found")
    return doc


def get_property_by_id(_id) -> dict:
    oid = _to_oid(_id, "Invalid property id")
    doc = properties_collection.find_one({"_id": oid})
    if not doc:
        raise PropertyNotFound(f"Property {oid} not found")
    return doc


def get_property_by_address(
    city_id, district_id, community_id, building: str, unit: str, room_no: str,
) -> Optional[dict]:
    code = generate_property_code(
        city_id, district_id, community_id,
        (building or "").strip(), (unit or "").strip(), (room_no or "").strip(),
    )
    return properties_collection.find_one({"property_code": code})
