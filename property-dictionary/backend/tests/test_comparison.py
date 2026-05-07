import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime
from bson import ObjectId

from database import db
from services.community_service import get_or_create_community
from services.property_service import get_or_create_property
from services.claim_service import submit_claims
from services.comparison import list_pending_discrepancies, get_discrepancy_by_id
from models.property import property_discrepancies_collection


@pytest.fixture(scope="module")
def test_city():
    doc = {"name": "_TEST_CMP_CITY_", "code": "CMP", "created_at": datetime.now()}
    result = db["cities"].insert_one(doc)
    yield result.inserted_id
    prop_ids = [p["_id"] for p in db["properties"].find({"city_id": result.inserted_id}, {"_id": 1})]
    db["property_discrepancies"].delete_many({"property_id": {"$in": prop_ids}})
    db["properties"].delete_many({"city_id": result.inserted_id})
    db["communities"].delete_many({"city_id": result.inserted_id})
    db["districts"].delete_many({"city_id": result.inserted_id})
    db["cities"].delete_one({"_id": result.inserted_id})


@pytest.fixture(scope="module")
def test_district(test_city):
    doc = {"city_id": test_city, "name": "_TEST_CMP_DIST_", "created_at": datetime.now()}
    result = db["districts"].insert_one(doc)
    yield result.inserted_id


@pytest.fixture
def fresh_property(test_city, test_district):
    suffix = str(ObjectId())[-6:]
    c = get_or_create_community(test_city, test_district, f"CMP小区_{suffix}")
    p = get_or_create_property(test_city, test_district, c["_id"], "1", "1", suffix)
    return p


@pytest.fixture
def fake_agent_listing():
    return ObjectId(), ObjectId()


# ============ first_claim ============

def test_first_claim_no_discrepancy(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    result = submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100})
    cmp = result["comparison_results"][0]
    assert cmp["consensus"] == "first_claim"
    assert cmp["discrepancy_id"] is None
    assert cmp["historical_values"] == []
    assert cmp["authoritative_value"] is None

# ============ consistent ============

def test_second_claim_consistent(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100})
    result = submit_claims(fresh_property["property_code"], ObjectId(), ObjectId(), {"area_sqm": 100})
    cmp = result["comparison_results"][0]
    assert cmp["consensus"] == "consistent"
    assert cmp["discrepancy_id"] is None
    assert len(cmp["historical_values"]) == 1

# ============ differs ============

def test_second_claim_differs_creates_discrepancy(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100})
    result = submit_claims(fresh_property["property_code"], ObjectId(), ObjectId(), {"area_sqm": 105})
    cmp = result["comparison_results"][0]
    assert cmp["consensus"] == "differs"
    assert cmp["discrepancy_id"] is not None
    assert cmp["new_value"] == 105
    assert cmp["historical_values"][0]["value"] == 100
    disc = get_discrepancy_by_id(cmp["discrepancy_id"])
    assert disc is not None
    assert disc["status"] == "pending"
    assert disc["field"] == "area_sqm"
    assert disc["new_value"] == 105

# ============ multi-field ============

def test_multifield_independent_comparison(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100, "floor": 5})
    result = submit_claims(fresh_property["property_code"], ObjectId(), ObjectId(), {"area_sqm": 100, "floor": 6})
    by = {r["field"]: r for r in result["comparison_results"]}
    assert by["area_sqm"]["consensus"] == "consistent"
    assert by["area_sqm"]["discrepancy_id"] is None
    assert by["floor"]["consensus"] == "differs"
    assert by["floor"]["discrepancy_id"] is not None

# ============ authoritative overrides history ============

def test_authoritative_overrides_history(fresh_property, fake_agent_listing):
    db["properties"].update_one(
        {"_id": fresh_property["_id"]},
        {"$set": {"authoritative_attrs": {"area_sqm": {"value": 100, "evidenced_by": "fixture",
            "reviewed_at": datetime.now(), "reviewed_by": ObjectId()}}}}
    )
    db["properties"].update_one(
        {"_id": fresh_property["_id"]},
        {"$push": {"attribute_claims": {"field": "area_sqm", "value": 105,
            "agent_id": ObjectId(), "listing_id": ObjectId(), "claimed_at": datetime.now()}}}
    )
    result = submit_claims(fresh_property["property_code"], fake_agent_listing[0], fake_agent_listing[1], {"area_sqm": 105})
    cmp = result["comparison_results"][0]
    assert cmp["consensus"] == "differs"
    assert cmp["authoritative_value"] == 100
    assert cmp["discrepancy_id"] is not None

# ============ list pending ============

def test_list_pending_discrepancies(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100})
    submit_claims(fresh_property["property_code"], ObjectId(), ObjectId(), {"area_sqm": 110})
    pending = list_pending_discrepancies(limit=100)
    pending_props = {d["property_id"] for d in pending}
    assert fresh_property["_id"] in pending_props
