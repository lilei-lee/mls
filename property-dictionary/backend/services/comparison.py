"""比对引擎 — 新 claim vs 权威值/历史, differs 时自动生成 discrepancy"""
from datetime import datetime
from bson import ObjectId
from typing import Optional

from database import db
from models.property import properties_collection, property_discrepancies_collection
from services.exceptions import (
    DictionaryError, InvalidIdentifier,
    DiscrepancyNotFound, DiscrepancyAlreadyReviewed,
)


def _get_authoritative(property_doc: dict, field: str):
    auth = (property_doc.get("authoritative_attrs") or {}).get(field)
    if isinstance(auth, dict):
        return auth.get("value")
    return None


def _historical_claims_for_field(property_doc: dict, field: str, exclude_indexes: set) -> list[dict]:
    all_claims = property_doc.get("attribute_claims", []) or []
    return [c for i, c in enumerate(all_claims) if c.get("field") == field and i not in exclude_indexes]


def _serialize_claim(c: dict) -> dict:
    return {
        "value": c["value"],
        "agent_id": str(c.get("agent_id", "")),
        "listing_id": str(c.get("listing_id", "")),
        "claimed_at": c["claimed_at"].isoformat() if c.get("claimed_at") else None,
    }


def compare_and_record_discrepancies(
    property_doc: dict, new_entries: list[dict], agent_id, listing_id,
) -> list[dict]:
    results = []
    total = len(property_doc.get("attribute_claims", []) or [])
    n = len(new_entries)
    new_indexes = set(range(total - n, total))

    for new_entry in new_entries:
        field = new_entry["field"]
        new_value = new_entry["value"]

        auth_value = _get_authoritative(property_doc, field)
        historical = _historical_claims_for_field(property_doc, field, new_indexes)
        historical_sorted = sorted(historical, key=lambda c: c.get("claimed_at") or datetime.min)

        baseline = auth_value if auth_value is not None else (
            historical_sorted[-1]["value"] if historical_sorted else None
        )

        if baseline is None:
            consensus = "first_claim"
        elif new_value == baseline:
            consensus = "consistent"
        else:
            consensus = "differs"

        discrepancy_id = None
        if consensus == "differs":
            now = datetime.now()
            disc_doc = {
                "property_id": property_doc["_id"],
                "listing_id": listing_id if isinstance(listing_id, ObjectId) else ObjectId(str(listing_id)),
                "agent_id": agent_id if isinstance(agent_id, ObjectId) else ObjectId(str(agent_id)),
                "field": field,
                "historical_values": [
                    {"value": c["value"], "agent_id": c.get("agent_id"),
                     "listing_id": c.get("listing_id"), "claimed_at": c.get("claimed_at")}
                    for c in historical_sorted
                ],
                "new_value": new_value,
                "authoritative_value": auth_value,
                "status": "pending",
                "evidence_urls": [],
                "reviewed_by": None, "reviewed_at": None, "resolution_note": None,
                "created_at": now,
            }
            insert_result = property_discrepancies_collection.insert_one(disc_doc)
            discrepancy_id = str(insert_result.inserted_id)

        results.append({
            "field": field, "new_value": new_value,
            "authoritative_value": auth_value,
            "historical_values": [_serialize_claim(c) for c in historical_sorted],
            "consensus": consensus, "discrepancy_id": discrepancy_id,
        })

    return results


def list_pending_discrepancies(city_id: Optional[str] = None, limit: int = 50) -> list[dict]:
    query = {"status": "pending"}
    docs = list(property_discrepancies_collection.find(query).sort("created_at", -1).limit(limit * 3))
    if city_id:
        try:
            city_oid = ObjectId(str(city_id))
        except Exception:
            return []
        prop_ids = [d["property_id"] for d in docs]
        matching_props = set(
            p["_id"] for p in properties_collection.find(
                {"_id": {"$in": prop_ids}, "city_id": city_oid}, {"_id": 1}
            )
        )
        docs = [d for d in docs if d["property_id"] in matching_props]
    return docs[:limit]


def get_discrepancy_by_id(disc_id: str) -> Optional[dict]:
    try:
        oid = ObjectId(disc_id)
    except Exception:
        return None
    return property_discrepancies_collection.find_one({"_id": oid})


# ============ Review 复核 ============

REVIEW_STATUSES = {"confirmed_new", "confirmed_history", "needs_evidence"}


def _set_authoritative_attr(property_id, field: str, value, reviewer_id, evidence_urls=None):
    auth_entry = {
        "value": value,
        "evidenced_by": evidence_urls or [],
        "reviewed_at": datetime.now(),
        "reviewed_by": reviewer_id,
    }
    properties_collection.update_one(
        {"_id": property_id},
        {
            "$set": {
                f"authoritative_attrs.{field}": auth_entry,
                "updated_at": datetime.now(),
            }
        }
    )


def review_discrepancy(
    discrepancy_id: str, status: str, reviewer_id,
    resolution_note: str = None, evidence_urls: list = None,
) -> dict:
    if status not in REVIEW_STATUSES:
        raise InvalidIdentifier(
            f"Invalid review status '{status}'. Allowed: {sorted(REVIEW_STATUSES)}"
        )
    try:
        disc_oid = ObjectId(discrepancy_id)
    except Exception:
        raise InvalidIdentifier(f"Invalid discrepancy_id: {discrepancy_id}")
    try:
        reviewer_oid = ObjectId(str(reviewer_id))
    except Exception:
        raise InvalidIdentifier(f"Invalid reviewer_id: {reviewer_id}")

    disc = property_discrepancies_collection.find_one({"_id": disc_oid})
    if not disc:
        raise DiscrepancyNotFound(f"Discrepancy {discrepancy_id} not found")
    if disc["status"] != "pending":
        raise DiscrepancyAlreadyReviewed(
            f"Discrepancy {discrepancy_id} already reviewed (status={disc['status']})"
        )

    field = disc["field"]
    if status == "confirmed_new":
        _set_authoritative_attr(disc["property_id"], field, disc["new_value"], reviewer_oid, evidence_urls)
    elif status == "confirmed_history":
        hist = disc.get("historical_values", [])
        if not hist:
            raise InvalidIdentifier("Cannot use confirmed_history when discrepancy has no historical values")
        _set_authoritative_attr(disc["property_id"], field, hist[-1]["value"], reviewer_oid, evidence_urls)

    now = datetime.now()
    update_doc = {
        "status": status, "reviewed_by": reviewer_oid,
        "reviewed_at": now, "resolution_note": resolution_note,
    }
    if evidence_urls:
        update_doc["evidence_urls"] = evidence_urls
    property_discrepancies_collection.update_one({"_id": disc_oid}, {"$set": update_doc})
    return property_discrepancies_collection.find_one({"_id": disc_oid})
