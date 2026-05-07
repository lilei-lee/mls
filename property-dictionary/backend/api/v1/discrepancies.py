"""discrepancy 查询 + 复核 REST API"""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional

from services.comparison import (
    list_pending_discrepancies, get_discrepancy_by_id, review_discrepancy,
)
from services.exceptions import (
    DictionaryError, InvalidIdentifier,
    DiscrepancyNotFound, DiscrepancyAlreadyReviewed,
)

router = APIRouter(prefix="/v1", tags=["discrepancies"])


def _map_disc_exception(e: DictionaryError) -> HTTPException:
    if isinstance(e, DiscrepancyNotFound):
        return HTTPException(status_code=404, detail=str(e))
    if isinstance(e, DiscrepancyAlreadyReviewed):
        return HTTPException(status_code=409, detail=str(e))
    if isinstance(e, InvalidIdentifier):
        return HTTPException(status_code=400, detail=str(e))
    return HTTPException(status_code=500, detail=str(e))


def _serialize_discrepancy(doc: dict) -> dict:
    return {
        "_id": str(doc["_id"]), "property_id": str(doc["property_id"]),
        "listing_id": str(doc["listing_id"]), "agent_id": str(doc["agent_id"]),
        "field": doc["field"],
        "historical_values": [
            {
                "value": h.get("value"),
                "agent_id": str(h["agent_id"]) if h.get("agent_id") else "",
                "listing_id": str(h["listing_id"]) if h.get("listing_id") else "",
                "claimed_at": h["claimed_at"].isoformat() if h.get("claimed_at") else None,
            }
            for h in doc.get("historical_values", [])
        ],
        "new_value": doc["new_value"],
        "authoritative_value": doc.get("authoritative_value"),
        "status": doc["status"],
        "evidence_urls": doc.get("evidence_urls", []),
        "reviewed_by": str(doc["reviewed_by"]) if doc.get("reviewed_by") else None,
        "reviewed_at": doc["reviewed_at"].isoformat() if doc.get("reviewed_at") else None,
        "resolution_note": doc.get("resolution_note"),
        "created_at": doc["created_at"].isoformat() if doc.get("created_at") else None,
    }


@router.get("/discrepancies")
def list_discrepancies(
    city_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
):
    docs = list_pending_discrepancies(city_id=city_id, limit=limit)
    return {"items": [_serialize_discrepancy(d) for d in docs], "total": len(docs)}


@router.get("/discrepancies/{disc_id}")
def get_discrepancy(disc_id: str):
    doc = get_discrepancy_by_id(disc_id)
    if not doc:
        raise HTTPException(status_code=404, detail=f"Discrepancy {disc_id} not found")
    return _serialize_discrepancy(doc)


# ============ Review ============

class ReviewBody(BaseModel):
    status: str = Field(..., description="confirmed_new / confirmed_history / needs_evidence")
    reviewer_id: str = Field(..., description="复核人(运营员工)ID")
    resolution_note: Optional[str] = Field(None, max_length=500)
    evidence_urls: list[str] = Field(default_factory=list)


@router.post("/discrepancies/{disc_id}/review")
def review(disc_id: str, body: ReviewBody):
    try:
        doc = review_discrepancy(
            discrepancy_id=disc_id, status=body.status,
            reviewer_id=body.reviewer_id, resolution_note=body.resolution_note,
            evidence_urls=body.evidence_urls,
        )
        return _serialize_discrepancy(doc)
    except DictionaryError as e:
        raise _map_disc_exception(e)
