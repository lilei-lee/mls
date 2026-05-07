"""community + property REST API"""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional

from services.community_service import (
    get_or_create_community, get_community_by_code, list_communities_by_city,
)
from services.property_service import (
    get_or_create_property, get_property_by_code, get_property_by_address,
)
from services.claim_service import submit_claims, list_claims_by_property
from services.exceptions import (
    DictionaryError, CityNotFound, DistrictNotFound, CommunityNotFound,
    PropertyNotFound, InvalidIdentifier, InvalidClaimField, InvalidClaimValue,
)

router = APIRouter(prefix="/v1", tags=["dictionary"])


# ============ 异常映射 ============

def _map_exception(e: DictionaryError) -> HTTPException:
    if isinstance(e, (CityNotFound, DistrictNotFound, CommunityNotFound, PropertyNotFound)):
        return HTTPException(status_code=404, detail=str(e))
    if isinstance(e, (InvalidClaimField, InvalidClaimValue)):
        return HTTPException(status_code=400, detail=str(e))
    if isinstance(e, InvalidIdentifier):
        return HTTPException(status_code=400, detail=str(e))
    return HTTPException(status_code=500, detail=str(e))


# ============ 序列化 ============

def _serialize_community(doc: dict) -> dict:
    return {
        "_id": str(doc["_id"]), "community_code": doc["community_code"],
        "city_id": str(doc["city_id"]), "district_id": str(doc["district_id"]),
        "name": doc["name"], "aliases": doc.get("aliases", []),
        "built_year": doc.get("built_year"),
        "total_buildings": doc.get("total_buildings"),
        "total_units": doc.get("total_units"),
        "property_type": doc.get("property_type"),
        "developer": doc.get("developer"),
        "property_management": doc.get("property_management"),
        "facilities": doc.get("facilities", {}),
        "standard_assets": doc.get("standard_assets", {}),
        "derived_stats": doc.get("derived_stats", {}),
        "authoritative_attrs": doc.get("authoritative_attrs", {}),
        "created_at": doc["created_at"].isoformat() if doc.get("created_at") else None,
    }


def _serialize_property(doc: dict) -> dict:
    return {
        "_id": str(doc["_id"]), "property_code": doc["property_code"],
        "city_id": str(doc["city_id"]), "district_id": str(doc["district_id"]),
        "community_id": str(doc["community_id"]),
        "building": doc["building"], "unit": doc["unit"], "room_no": doc["room_no"],
        "authoritative_attrs": doc.get("authoritative_attrs", {}),
        "attribute_claims": doc.get("attribute_claims", []),
        "transaction_history": doc.get("transaction_history", []),
        "listing_history": doc.get("listing_history", []),
        "standard_assets": doc.get("standard_assets", {}),
        "created_at": doc["created_at"].isoformat() if doc.get("created_at") else None,
        "updated_at": doc["updated_at"].isoformat() if doc.get("updated_at") else None,
    }


# ============ Request models ============

class IdentifyCommunityBody(BaseModel):
    city_id: str = Field(..., description="城市 ObjectId 字符串")
    district_id: str = Field(..., description="区县 ObjectId 字符串")
    name: str = Field(..., min_length=1, max_length=100, description="小区名")


class IdentifyPropertyBody(BaseModel):
    city_id: str; district_id: str; community_id: str
    building: str = Field(..., min_length=1, max_length=20)
    unit: str = Field(..., min_length=1, max_length=20)
    room_no: str = Field(..., min_length=1, max_length=20)


# ============ Endpoints ============

@router.post("/communities/identify")
def identify_community(body: IdentifyCommunityBody):
    try:
        doc = get_or_create_community(body.city_id, body.district_id, body.name)
        return _serialize_community(doc)
    except DictionaryError as e:
        raise _map_exception(e)


@router.get("/communities/{code}")
def get_community(code: str):
    try:
        doc = get_community_by_code(code)
        return _serialize_community(doc)
    except DictionaryError as e:
        raise _map_exception(e)


@router.get("/communities")
def list_communities(
    city_id: str = Query(..., description="城市 ID"),
    keyword: Optional[str] = Query(None, description="模糊搜索关键词"),
    limit: int = Query(50, ge=1, le=200),
):
    try:
        docs = list_communities_by_city(city_id, name_keyword=keyword, limit=limit)
        return {"items": [_serialize_community(d) for d in docs], "total": len(docs)}
    except DictionaryError as e:
        raise _map_exception(e)


@router.post("/properties/identify")
def identify_property(body: IdentifyPropertyBody):
    try:
        doc = get_or_create_property(
            body.city_id, body.district_id, body.community_id,
            body.building, body.unit, body.room_no,
        )
        return _serialize_property(doc)
    except DictionaryError as e:
        raise _map_exception(e)


@router.get("/properties/by-address")
def get_property_by_addr(
    city_id: str = Query(...), district_id: str = Query(...),
    community_id: str = Query(...), building: str = Query(...),
    unit: str = Query(...), room_no: str = Query(...),
):
    doc = get_property_by_address(city_id, district_id, community_id, building, unit, room_no)
    if not doc:
        raise HTTPException(status_code=404, detail="Property not found at this address")
    return _serialize_property(doc)


@router.get("/properties/{code}")
def get_property(code: str):
    try:
        doc = get_property_by_code(code)
        return _serialize_property(doc)
    except DictionaryError as e:
        raise _map_exception(e)


# ============ Claim endpoints ============

class SubmitClaimsBody(BaseModel):
    agent_id: str = Field(..., description="提交者(经纪人)ID")
    listing_id: str = Field(..., description="关联 listing ID")
    claims: dict = Field(..., description="字段-值字典,如 {area_sqm: 105, floor: 5}")


@router.post("/properties/{code}/claims")
def post_claims(code: str, body: SubmitClaimsBody):
    try:
        return submit_claims(code, body.agent_id, body.listing_id, body.claims)
    except DictionaryError as e:
        raise _map_exception(e)


@router.get("/properties/{code}/claims")
def list_claims(code: str, field: Optional[str] = Query(None)):
    try:
        return {"property_code": code, "items": list_claims_by_property(code, field=field)}
    except DictionaryError as e:
        raise _map_exception(e)
