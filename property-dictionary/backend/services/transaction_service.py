"""transaction sink — 历史成交价沉淀到 property.transaction_history"""
from datetime import datetime, date
from typing import Optional
from bson import ObjectId

from services.property_service import get_property_by_code
from services.exceptions import InvalidTransactionData, TransactionAlreadyRecorded
from models.property import properties_collection

SOURCE_WHITELIST = {"mls_internal", "external_bezzy", "external_lianjia", "govt_record", "external_other"}


def _validate_deal_date(deal_date: str) -> str:
    if not isinstance(deal_date, str):
        raise InvalidTransactionData(f"deal_date must be ISO date string, got {type(deal_date).__name__}")
    try:
        parsed = date.fromisoformat(deal_date)
    except ValueError:
        raise InvalidTransactionData(f"deal_date '{deal_date}' is not a valid ISO date (YYYY-MM-DD)")
    if parsed > date.today():
        raise InvalidTransactionData(f"deal_date '{deal_date}' is in the future")
    return parsed.isoformat()


def record_transaction(
    property_code: str, deal_price_yuan: int, deal_date: str,
    source: str = "mls_internal", transaction_id: Optional[str] = None,
    verified: bool = False,
) -> dict:
    prop = get_property_by_code(property_code)

    if not isinstance(deal_price_yuan, int):
        raise InvalidTransactionData(f"deal_price_yuan must be int, got {type(deal_price_yuan).__name__}")
    if deal_price_yuan <= 0:
        raise InvalidTransactionData(f"deal_price_yuan must be > 0, got {deal_price_yuan}")

    deal_date = _validate_deal_date(deal_date)

    if source not in SOURCE_WHITELIST:
        raise InvalidTransactionData(f"source '{source}' not in whitelist. Allowed: {sorted(SOURCE_WHITELIST)}")

    history = prop.get("transaction_history", []) or []
    if transaction_id:
        for entry in history:
            if entry.get("transaction_id") == transaction_id:
                return {
                    "property_code": property_code, "transaction_id": transaction_id,
                    "added": False, "total_transactions_after": len(history),
                }

    now = datetime.now()
    new_entry = {
        "deal_price_yuan": deal_price_yuan, "deal_date": deal_date,
        "transaction_id": transaction_id, "source": source,
        "verified": verified, "created_at": now,
    }
    properties_collection.update_one(
        {"_id": prop["_id"]},
        {"$push": {"transaction_history": new_entry}, "$set": {"updated_at": now}}
    )
    return {
        "property_code": property_code, "transaction_id": transaction_id,
        "added": True, "total_transactions_after": len(history) + 1,
    }


def list_transaction_history(property_code: str, source: Optional[str] = None, limit: int = 100) -> list[dict]:
    prop = get_property_by_code(property_code)
    history = prop.get("transaction_history", []) or []
    if source:
        history = [h for h in history if h.get("source") == source]
    history_sorted = sorted(history, key=lambda h: h.get("deal_date") or "", reverse=True)
    return [
        {
            "deal_price_yuan": h["deal_price_yuan"], "deal_date": h["deal_date"],
            "transaction_id": h.get("transaction_id"), "source": h["source"],
            "verified": h.get("verified", False),
            "created_at": h["created_at"].isoformat() if h.get("created_at") else None,
        }
        for h in history_sorted[:limit]
    ]
