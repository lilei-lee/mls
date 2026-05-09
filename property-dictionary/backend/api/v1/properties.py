"""community + property REST API"""
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional

from models.community import communities_collection
from services.community_service import (
    get_or_create_community, get_community_by_code, list_communities_by_city,
)
from services.property_service import (
    get_or_create_property, get_property_by_code, get_property_by_address,
)
from services.claim_service import submit_claims, list_claims_by_property
from services.transaction_service import record_transaction, list_transaction_history
from services.exceptions import (
    DictionaryError, CityNotFound, DistrictNotFound, CommunityNotFound,
    PropertyNotFound, InvalidIdentifier, InvalidClaimField, InvalidClaimValue,
    InvalidTransactionData, TransactionAlreadyRecorded,
)

from api.auth import require_api_key, check_city_scope

router = APIRouter(
    prefix="/v1", tags=["dictionary"],
    dependencies=[Depends(require_api_key)],
)


# ============ 异常映射 ============

def _map_exception(e: DictionaryError) -> HTTPException:
    if isinstance(e, (CityNotFound, DistrictNotFound, CommunityNotFound, PropertyNotFound)):
        return HTTPException(status_code=404, detail=str(e))
    if isinstance(e, (InvalidClaimField, InvalidClaimValue, InvalidTransactionData)):
        return HTTPException(status_code=400, detail=str(e))
    if isinstance(e, TransactionAlreadyRecorded):
        return HTTPException(status_code=409, detail=str(e))
    if isinstance(e, InvalidIdentifier):
        return HTTPException(status_code=400, detail=str(e))
    return HTTPException(status_code=500, detail=str(e))


# ============ 序列化 ============

def _serialize_community(doc: dict) -> dict:
    return {
        "_id": str(doc["_id"]), "community_code": doc["community_code"],
        "city_id": str(doc["city_id"]), "district_id": str(doc["district_id"]),
        "name": doc["name"], "aliases": doc.get("aliases", []),
        # 基础
        "built_year": doc.get("built_year"),
        "bld_year_start": doc.get("bld_year_start"),
        "bld_year_end": doc.get("bld_year_end"),
        "total_buildings": doc.get("total_buildings"),
        "total_units": doc.get("total_units"),
        # 规划
        "plot_ratio": doc.get("plot_ratio"),
        "green_ratio": doc.get("green_ratio"),
        # 物业
        "property_type": doc.get("property_type"),
        "developer": doc.get("developer"),
        "property_management": doc.get("property_management"),
        "property_company": doc.get("property_company"),
        "property_fee_yuan": doc.get("property_fee_yuan"),
        "building_types": doc.get("building_types"),
        # 供暖
        "heating_type": doc.get("heating_type"),
        # 教育
        "primary_school": doc.get("primary_school"),
        "middle_school": doc.get("middle_school"),
        # 交通
        "nearest_highway": doc.get("nearest_highway"),
        "nearest_train_station": doc.get("nearest_train_station"),
        # 生活
        "nearby_market": doc.get("nearby_market"),
        "nearby_hospital": doc.get("nearby_hospital"),
        # 车位
        "parking_total": doc.get("parking_total"),
        "parking_ratio": doc.get("parking_ratio"),
        # 既有
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
        "objective_features": doc.get("objective_features"),
        "decoration": doc.get("decoration"),
        "attribute_claims": [
            {
                "field": c["field"], "value": c["value"],
                "agent_id": str(c["agent_id"]) if c.get("agent_id") else None,
                "listing_id": str(c["listing_id"]) if c.get("listing_id") else None,
                "claimed_at": c["claimed_at"].isoformat() if c.get("claimed_at") else None,
            }
            for c in doc.get("attribute_claims", [])
        ],
        "transaction_history": [
            {
                "deal_price_yuan": t["deal_price_yuan"], "deal_date": t["deal_date"],
                "transaction_id": str(t["transaction_id"]) if t.get("transaction_id") else None,
                "source": t["source"], "verified": t.get("verified", False),
                "created_at": t["created_at"].isoformat() if t.get("created_at") else None,
            }
            for t in doc.get("transaction_history", [])
        ],
        "listing_history": [
            {
                "list_price_wan": l["list_price_wan"],
                "listed_at": l["listed_at"].isoformat() if l.get("listed_at") else None,
                "delisted_at": l["delisted_at"].isoformat() if l.get("delisted_at") else None,
                "sold": l.get("sold", False),
                "listing_id": str(l["listing_id"]) if l.get("listing_id") else None,
                "source": l["source"],
            }
            for l in doc.get("listing_history", [])
        ],
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
def identify_community(body: IdentifyCommunityBody, api_key_meta: dict = Depends(require_api_key)):
    check_city_scope(api_key_meta, body.city_id)
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
    api_key_meta: dict = Depends(require_api_key),
):
    check_city_scope(api_key_meta, city_id)
    try:
        docs = list_communities_by_city(city_id, name_keyword=keyword, limit=limit)
        return {"items": [_serialize_community(d) for d in docs], "total": len(docs)}
    except DictionaryError as e:
        raise _map_exception(e)


# ── Community Batch ──

class CommunityBatchBody(BaseModel):
    community_ids: list[str] = Field(..., min_length=1, max_length=100)


@router.post("/communities/batch")
def batch_get_communities(body: CommunityBatchBody, api_key_meta: dict = Depends(require_api_key)):
    try:
        from bson import ObjectId
        oids = [ObjectId(cid) for cid in body.community_ids]
        docs = list(communities_collection.find({"_id": {"$in": oids}}))
        return [_serialize_community(d) for d in docs]
    except DictionaryError as e:
        raise _map_exception(e)


@router.post("/properties/identify")
def identify_property(body: IdentifyPropertyBody, api_key_meta: dict = Depends(require_api_key)):
    check_city_scope(api_key_meta, body.city_id)
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
    api_key_meta: dict = Depends(require_api_key),
):
    check_city_scope(api_key_meta, city_id)
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
    listing_id: Optional[str] = Field(None, description="关联 listing ID(V2.1:MLS 挂牌时 listing 还未写库,可为空)")
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


# ============ Transaction sink ============

class RecordTransactionBody(BaseModel):
    deal_price_yuan: int = Field(..., gt=0, description="成交价(元,整数)")
    deal_date: str = Field(..., description="ISO 日期 YYYY-MM-DD")
    source: str = Field("mls_internal", description="数据来源(枚举)")
    transaction_id: Optional[str] = Field(None, description="MLS 端 tx _id 或外部唯一标识,用于幂等")
    verified: bool = Field(False, description="是否已核实")


@router.post("/properties/{code}/transactions")
def post_transaction(code: str, body: RecordTransactionBody):
    try:
        return record_transaction(
            property_code=code, deal_price_yuan=body.deal_price_yuan,
            deal_date=body.deal_date, source=body.source,
            transaction_id=body.transaction_id, verified=body.verified,
        )
    except DictionaryError as e:
        raise _map_exception(e)


@router.get("/properties/{code}/transactions")
def list_transactions(code: str, source: Optional[str] = Query(None), limit: int = Query(100, ge=1, le=500)):
    try:
        items = list_transaction_history(code, source=source, limit=limit)
        return {"property_code": code, "items": items, "total": len(items)}
    except DictionaryError as e:
        raise _map_exception(e)


# ============ Batch ============

class BatchGetBody(BaseModel):
    codes: list[str] = Field(..., min_length=1, max_length=100, description="property_code 列表(1-100)")


def _serialize_batch_item(doc: dict) -> dict:
    claims = doc.get("attribute_claims", []) or []
    latest_claims = {}
    if claims:
        sorted_claims = sorted(claims, key=lambda c: c.get("claimed_at") or "", reverse=True)
        seen = set()
        for c in sorted_claims:
            if c["field"] not in seen:
                latest_claims[c["field"]] = c["value"]
                seen.add(c["field"])

    return {
        "property_code": doc["property_code"],
        "city_id": str(doc["city_id"]),
        "district_id": str(doc["district_id"]),
        "community_id": str(doc["community_id"]),
        "building": doc["building"],
        "unit": doc["unit"],
        "room_no": doc["room_no"],
        "authoritative_attrs": doc.get("authoritative_attrs", {}),
        "attribute_claims_latest": latest_claims if latest_claims else None,
        "standard_assets": doc.get("standard_assets", {}),
        "transaction_history_count": len(doc.get("transaction_history", [])),
    }


@router.post("/properties/batch")
def batch_get_properties(body: BatchGetBody, api_key_meta: dict = Depends(require_api_key)):
    try:
        from models.property import properties_collection
        codes = body.codes
        docs = list(properties_collection.find({"property_code": {"$in": codes}}))
        by_code = {d["property_code"]: d for d in docs}

        # city_scope: check all found properties
        for doc in docs:
            check_city_scope(api_key_meta, str(doc["city_id"]))

        result = {}
        for code in codes:
            doc = by_code.get(code)
            result[code] = _serialize_batch_item(doc) if doc else None

        return result
    except DictionaryError as e:
        raise _map_exception(e)
