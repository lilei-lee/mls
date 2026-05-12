import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime
from bson import ObjectId

from database import db
from services.community_service import get_or_create_community
from services.property_service import get_or_create_property
from services.claim_service import submit_claims, list_claims_by_property
from services.exceptions import InvalidClaimField, InvalidClaimValue, PropertyNotFound


@pytest.fixture(scope="module")
def test_city():
    doc = {"name": "_TEST_CLAIM_CITY_", "code": "TCC", "created_at": datetime.now()}
    result = db["cities"].insert_one(doc)
    yield result.inserted_id
    db["properties"].delete_many({"city_id": result.inserted_id})
    db["communities"].delete_many({"city_id": result.inserted_id})
    db["districts"].delete_many({"city_id": result.inserted_id})
    db["cities"].delete_one({"_id": result.inserted_id})


@pytest.fixture(scope="module")
def test_district(test_city):
    doc = {"city_id": test_city, "name": "_TEST_CLAIM_DISTRICT_", "created_at": datetime.now()}
    result = db["districts"].insert_one(doc)
    yield result.inserted_id


@pytest.fixture
def fresh_property(test_city, test_district):
    suffix = str(ObjectId())[-6:]
    c = get_or_create_community(test_city, test_district, f"Claim测试小区_{suffix}")
    p = get_or_create_property(test_city, test_district, c["_id"], "1", "1", suffix)
    return p


@pytest.fixture
def fake_agent_listing():
    return ObjectId(), ObjectId()


# ============ 正常提交 ============

def test_submit_single_claim(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    result = submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 105.5})
    assert result["total_claims_after"] == 1
    assert len(result["claims_added"]) == 1
    assert result["claims_added"][0]["field"] == "area_sqm"
    assert result["claims_added"][0]["value"] == 105.5

def test_submit_multi_field(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    result = submit_claims(fresh_property["property_code"], agent_id, listing_id,
        {"area_sqm": 100, "floor": 5, "total_floor": 18, "rooms": 3, "bathrooms": 2})
    assert result["total_claims_after"] == 5
    assert len(result["claims_added"]) == 5

def test_claim_accumulates_across_submissions(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100})
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 105})
    claims = list_claims_by_property(fresh_property["property_code"], field="area_sqm")
    assert len(claims) == 2
    assert claims[0]["value"] == 100
    assert claims[1]["value"] == 105

# ============ 校验失败 ============

def test_invalid_field_rejected(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(InvalidClaimField):
        submit_claims(fresh_property["property_code"], agent_id, listing_id, {"price_wan": 500})

def test_invalid_value_type(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(InvalidClaimValue):
        submit_claims(fresh_property["property_code"], agent_id, listing_id, {"floor": 5.5})

def test_negative_area_rejected(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(InvalidClaimValue):
        submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": -10})

def test_zero_floor_rejected(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(InvalidClaimValue):
        submit_claims(fresh_property["property_code"], agent_id, listing_id, {"floor": 0})

def test_partial_failure_atomic(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(InvalidClaimField):
        submit_claims(fresh_property["property_code"], agent_id, listing_id,
            {"area_sqm": 100, "bogus_field": 999})
    claims = list_claims_by_property(fresh_property["property_code"])
    assert len(claims) == 0

def test_empty_claims_rejected(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(InvalidClaimField):
        submit_claims(fresh_property["property_code"], agent_id, listing_id, {})

def test_submit_to_nonexistent_property(fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    with pytest.raises(PropertyNotFound):
        submit_claims("ZZZZZZZZZZZZ", agent_id, listing_id, {"area_sqm": 100})

# ============ list_claims ============

def test_list_claims_filtered_by_field(fresh_property, fake_agent_listing):
    agent_id, listing_id = fake_agent_listing
    submit_claims(fresh_property["property_code"], agent_id, listing_id, {"area_sqm": 100, "floor": 5})
    assert len(list_claims_by_property(fresh_property["property_code"], field="area_sqm")) == 1
    assert len(list_claims_by_property(fresh_property["property_code"], field="floor")) == 1
    assert len(list_claims_by_property(fresh_property["property_code"])) == 2


def test_submit_claim_listing_id_none(fresh_property):
    """V2.1 #15: listing_id 为空时(MLS 挂牌 listing 还没写库),正常写 claim"""
    from bson import ObjectId
    r = submit_claims(fresh_property["property_code"], ObjectId(), None, {"area_sqm": 99})
    assert r["total_claims_after"] == 1
    assert r["claims_added"][0]["listing_id"] is None
