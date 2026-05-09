"""claim 提交业务逻辑 — LA 对 property 物理属性的声明"""
from datetime import datetime
from typing import Optional
from bson import ObjectId

from services.property_service import get_property_by_code
from services.community_service import _to_oid
from services.exceptions import InvalidClaimField, InvalidClaimValue
from services.comparison import compare_and_record_discrepancies
from models.property import properties_collection

CLAIM_FIELD_WHITELIST = {
    "area_sqm": (int, float),
    "floor": int,
    "total_floor": int,
    "rooms": int,
    "halls": int,
    "bathrooms": int,
    "objective_features": list,
    "decoration": str,
}


def _validate_claim_field(field: str, value) -> None:
    if field not in CLAIM_FIELD_WHITELIST:
        raise InvalidClaimField(
            f"Field '{field}' not in claim whitelist. "
            f"Allowed: {sorted(CLAIM_FIELD_WHITELIST.keys())}"
        )
    expected = CLAIM_FIELD_WHITELIST[field]
    if not isinstance(value, expected):
        raise InvalidClaimValue(
            f"Field '{field}' expects {expected}, got {type(value).__name__}: {value!r}"
        )
    if field in ("area_sqm",):
        if value <= 0:
            raise InvalidClaimValue(f"area_sqm must be > 0, got {value}")
    if field in ("floor", "total_floor"):
        if value < 1:
            raise InvalidClaimValue(f"{field} must be >= 1, got {value}")
    if field in ("rooms", "halls", "bathrooms"):
        if value < 0:
            raise InvalidClaimValue(f"{field} must be >= 0, got {value}")


def submit_claims(property_code: str, agent_id, listing_id, claims: dict) -> dict:
    prop = get_property_by_code(property_code)
    agent_oid = _to_oid(agent_id, "Invalid agent_id")
    # V2.1 #15 段 7.3: listing_id 允许为空(MLS 挂牌时 listing 还没写库)
    listing_oid = _to_oid(listing_id, "Invalid listing_id") if listing_id else None

    if not isinstance(claims, dict) or not claims:
        raise InvalidClaimField("claims must be a non-empty dict")

    for field, value in claims.items():
        _validate_claim_field(field, value)

    now = datetime.now()
    claim_entries = [
        {
            "field": field, "value": value,
            "agent_id": agent_oid, "listing_id": listing_oid,
            "claimed_at": now,
        }
        for field, value in claims.items()
    ]

    properties_collection.update_one(
        {"_id": prop["_id"]},
        {
            "$push": {"attribute_claims": {"$each": claim_entries}},
            "$set": {"updated_at": now},
        }
    )

    updated = properties_collection.find_one({"_id": prop["_id"]})

    # 比对引擎:每条新 claim 独立比对,不一致时自动生成 discrepancy
    comparison_results = compare_and_record_discrepancies(
        property_doc=updated,
        new_entries=claim_entries,
        agent_id=agent_oid,
        listing_id=listing_oid,
    )

    return {
        "property_code": property_code,
        "claims_added": [
            {
                "field": e["field"], "value": e["value"],
                "agent_id": str(e["agent_id"]),
                "listing_id": str(e["listing_id"]) if e["listing_id"] else None,
                "claimed_at": e["claimed_at"].isoformat(),
            }
            for e in claim_entries
        ],
        "total_claims_after": len(updated.get("attribute_claims", [])),
        "comparison_results": comparison_results,
    }


def list_claims_by_property(property_code: str, field: Optional[str] = None) -> list[dict]:
    prop = get_property_by_code(property_code)
    claims = prop.get("attribute_claims", [])
    if field:
        claims = [c for c in claims if c.get("field") == field]
    return [
        {
            "field": c["field"], "value": c["value"],
            "agent_id": str(c.get("agent_id", "")),
            "listing_id": str(c.get("listing_id", "")),
            "claimed_at": c["claimed_at"].isoformat() if c.get("claimed_at") else None,
        }
        for c in claims
    ]
