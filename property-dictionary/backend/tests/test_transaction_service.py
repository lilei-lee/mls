import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime, timedelta
from bson import ObjectId

from database import db
from services.community_service import get_or_create_community
from services.property_service import get_or_create_property
from services.transaction_service import record_transaction, list_transaction_history
from services.exceptions import InvalidTransactionData, PropertyNotFound


@pytest.fixture(scope="module")
def test_city():
    doc = {"name": "_TEST_TX_CITY_", "code": "TXX", "created_at": datetime.now()}
    result = db["cities"].insert_one(doc)
    yield result.inserted_id
    db["properties"].delete_many({"city_id": result.inserted_id})
    db["communities"].delete_many({"city_id": result.inserted_id})
    db["districts"].delete_many({"city_id": result.inserted_id})
    db["cities"].delete_one({"_id": result.inserted_id})


@pytest.fixture(scope="module")
def test_district(test_city):
    doc = {"city_id": test_city, "name": "_TEST_TX_DIST_", "created_at": datetime.now()}
    result = db["districts"].insert_one(doc)
    yield result.inserted_id


@pytest.fixture
def fresh_property(test_city, test_district):
    suffix = str(ObjectId())[-6:]
    c = get_or_create_community(test_city, test_district, f"TX小区_{suffix}")
    p = get_or_create_property(test_city, test_district, c["_id"], "1", "1", suffix)
    return p


# ============ normal ============

def test_record_basic(fresh_property):
    r = record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", "mls_internal", str(ObjectId()))
    assert r["added"] is True and r["total_transactions_after"] == 1

def test_record_multiple(fresh_property):
    record_transaction(fresh_property["property_code"], 6100000, "2025-06-15", "mls_internal", str(ObjectId()))
    r = record_transaction(fresh_property["property_code"], 6500000, "2026-04-23", "mls_internal", str(ObjectId()))
    assert r["total_transactions_after"] == 2

# ============ idempotent ============

def test_idempotent_same_txn_id(fresh_property):
    tid = str(ObjectId())
    r1 = record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", "mls_internal", tid)
    r2 = record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", "mls_internal", tid)
    assert r1["added"] is True and r2["added"] is False and r2["total_transactions_after"] == 1

def test_no_idempotent_without_txn_id(fresh_property):
    r1 = record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", "external_bezzy", None)
    r2 = record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", "external_bezzy", None)
    assert r1["added"] and r2["added"] and r2["total_transactions_after"] == 2

# ============ validation ============

def test_price_negative(fresh_property):
    with pytest.raises(InvalidTransactionData): record_transaction(fresh_property["property_code"], -100, "2026-04-23")

def test_price_zero(fresh_property):
    with pytest.raises(InvalidTransactionData): record_transaction(fresh_property["property_code"], 0, "2026-04-23")

def test_price_type(fresh_property):
    with pytest.raises(InvalidTransactionData): record_transaction(fresh_property["property_code"], "6100000", "2026-04-23")

def test_date_format(fresh_property):
    with pytest.raises(InvalidTransactionData): record_transaction(fresh_property["property_code"], 6100000, "2026/04/23")

def test_date_future(fresh_property):
    fut = (datetime.now().date() + timedelta(days=30)).isoformat()
    with pytest.raises(InvalidTransactionData): record_transaction(fresh_property["property_code"], 6100000, fut)

def test_invalid_source(fresh_property):
    with pytest.raises(InvalidTransactionData): record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", source="bogus")

def test_property_not_found():
    with pytest.raises(PropertyNotFound): record_transaction("ZZZZZZZZZZZZ", 6100000, "2026-04-23")

# ============ history ============

def test_list_history_sorted(fresh_property):
    record_transaction(fresh_property["property_code"], 5000000, "2024-01-15", source="external_bezzy")
    record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", source="mls_internal")
    record_transaction(fresh_property["property_code"], 5500000, "2025-08-10", source="external_lianjia")
    h = list_transaction_history(fresh_property["property_code"])
    assert len(h) == 3
    assert h[0]["deal_date"] == "2026-04-23"
    assert h[1]["deal_date"] == "2025-08-10"
    assert h[2]["deal_date"] == "2024-01-15"

def test_list_history_filtered(fresh_property):
    record_transaction(fresh_property["property_code"], 5000000, "2024-01-15", source="external_bezzy")
    record_transaction(fresh_property["property_code"], 6100000, "2026-04-23", source="mls_internal")
    b = list_transaction_history(fresh_property["property_code"], source="external_bezzy")
    assert len(b) == 1 and b[0]["source"] == "external_bezzy"
