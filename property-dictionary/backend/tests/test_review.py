import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime
from bson import ObjectId

from database import db
from services.community_service import get_or_create_community
from services.property_service import get_or_create_property
from services.claim_service import submit_claims
from services.comparison import review_discrepancy
from services.exceptions import DiscrepancyNotFound, DiscrepancyAlreadyReviewed, InvalidIdentifier
from models.property import properties_collection


@pytest.fixture(scope="module")
def test_city():
    doc = {"name": "_TEST_RV_CITY_", "code": "RVW", "created_at": datetime.now()}
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
    doc = {"city_id": test_city, "name": "_TEST_RV_DIST_", "created_at": datetime.now()}
    result = db["districts"].insert_one(doc)
    yield result.inserted_id


@pytest.fixture
def discrepancy_setup(test_city, test_district):
    suffix = str(ObjectId())[-6:]
    c = get_or_create_community(test_city, test_district, f"RV小区_{suffix}")
    p = get_or_create_property(test_city, test_district, c["_id"], "1", "1", suffix)
    submit_claims(p["property_code"], ObjectId(), ObjectId(), {"area_sqm": 100})
    result = submit_claims(p["property_code"], ObjectId(), ObjectId(), {"area_sqm": 105})
    disc_id = result["comparison_results"][0]["discrepancy_id"]
    return {"property_id": p["_id"], "property_code": p["property_code"], "disc_id": disc_id}


# ============ confirmed_new ============

def test_confirm_new_updates_authoritative(discrepancy_setup):
    doc = review_discrepancy(discrepancy_setup["disc_id"], "confirmed_new", ObjectId(), resolution_note="新值正确")
    assert doc["status"] == "confirmed_new"
    assert doc["resolution_note"] == "新值正确"
    p = properties_collection.find_one({"_id": discrepancy_setup["property_id"]})
    assert p["authoritative_attrs"]["area_sqm"]["value"] == 105

# ============ confirmed_history ============

def test_confirm_history_updates_authoritative(discrepancy_setup):
    doc = review_discrepancy(discrepancy_setup["disc_id"], "confirmed_history", ObjectId())
    assert doc["status"] == "confirmed_history"
    p = properties_collection.find_one({"_id": discrepancy_setup["property_id"]})
    assert p["authoritative_attrs"]["area_sqm"]["value"] == 100

# ============ needs_evidence ============

def test_needs_evidence_no_authoritative(discrepancy_setup):
    doc = review_discrepancy(discrepancy_setup["disc_id"], "needs_evidence", ObjectId(), resolution_note="待LA上传房本")
    assert doc["status"] == "needs_evidence"
    p = properties_collection.find_one({"_id": discrepancy_setup["property_id"]})
    assert "area_sqm" not in p.get("authoritative_attrs", {})

# ============ errors ============

def test_invalid_status_rejected(discrepancy_setup):
    with pytest.raises(InvalidIdentifier):
        review_discrepancy(discrepancy_setup["disc_id"], "bogus_status", ObjectId())

def test_nonexistent_discrepancy():
    with pytest.raises(DiscrepancyNotFound):
        review_discrepancy("000000000000000000000000", "confirmed_new", ObjectId())

def test_already_reviewed_rejected(discrepancy_setup):
    review_discrepancy(discrepancy_setup["disc_id"], "confirmed_new", ObjectId())
    with pytest.raises(DiscrepancyAlreadyReviewed):
        review_discrepancy(discrepancy_setup["disc_id"], "confirmed_new", ObjectId())

def test_invalid_disc_id():
    with pytest.raises(InvalidIdentifier):
        review_discrepancy("not-a-valid-oid", "confirmed_new", ObjectId())

# ============ authoritative takes effect ============

def test_authoritative_takes_effect_for_subsequent_claims(discrepancy_setup):
    review_discrepancy(discrepancy_setup["disc_id"], "confirmed_new", ObjectId())
    result = submit_claims(discrepancy_setup["property_code"], ObjectId(), ObjectId(), {"area_sqm": 100})
    cmp = result["comparison_results"][0]
    assert cmp["consensus"] == "differs"
    assert cmp["authoritative_value"] == 105
