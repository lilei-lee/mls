"""V2.2 #1 新字段单测"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime
from bson import ObjectId
from database import db

@pytest.fixture
def test_city():
    doc = {"name": f"_V22_{ObjectId()}", "code": "V22", "created_at": datetime.now()}
    r = db["cities"].insert_one(doc)
    yield r
    db["properties"].delete_many({"city_id": r})
    db["communities"].delete_many({"city_id": r})
    db["districts"].delete_many({"city_id": r})
    db["cities"].delete_one({"_id": r})

@pytest.fixture
def test_district(test_city):
    doc = {"city_id": test_city, "name": f"_V22D_{ObjectId()}", "created_at": datetime.now()}
    yield db["districts"].insert_one(doc)

@pytest.fixture
def ctx(test_city, test_district):
    from services.community_service import get_or_create_community
    from services.property_service import get_or_create_property
    c = get_or_create_community(test_city, test_district, f"V22_{str(ObjectId())[-4:]}")
    p = get_or_create_property(test_city, test_district, c["_id"], "1", "1", str(ObjectId())[-4:])
    return {"city": test_city, "district": test_district, "community": c, "property": p}

# ── Community ──

def test_community_features_schema():
    from models.community import CommunityDoc
    fields = list(CommunityDoc.model_fields.keys())
    for f in ["bld_year_start","bld_year_end","plot_ratio","green_ratio",
              "property_company","property_fee_yuan","building_types",
              "heating_type","primary_school","middle_school",
              "nearest_highway","nearest_train_station",
              "nearby_market","nearby_hospital","parking_total","parking_ratio"]:
        assert f in fields, f"{f} missing"

def test_community_get_returns_features(ctx):
    from api.v1.properties import _serialize_community
    r = _serialize_community(ctx["community"])
    for f in ["bld_year_start","plot_ratio","heating_type","parking_total"]:
        assert f in r, f"{f} missing"

# ── Property ──

def test_property_claim_objective_features(ctx):
    from services.claim_service import submit_claims
    r = submit_claims(ctx["property"]["property_code"], ObjectId(), ObjectId(),
                      {"objective_features": ["南北通透", "全明格局"]})
    assert r["total_claims_after"] >= 1

def test_property_claim_decoration(ctx):
    from services.claim_service import submit_claims
    r = submit_claims(ctx["property"]["property_code"], ObjectId(), ObjectId(),
                      {"decoration": "精装"})
    assert r["total_claims_after"] >= 1

def test_property_serialize(ctx):
    from services.claim_service import submit_claims
    from models.property import properties_collection
    from api.v1.properties import _serialize_property
    submit_claims(ctx["property"]["property_code"], ObjectId(), ObjectId(),
                  {"objective_features": ["客厅朝南"], "decoration": "豪装"})
    p = properties_collection.find_one({"_id": ctx["property"]["_id"]})
    r = _serialize_property(p)
    assert "objective_features" in r
    assert "decoration" in r

def test_claim_invalid_rejected(ctx):
    from services.claim_service import submit_claims
    from services.exceptions import InvalidClaimValue
    with pytest.raises(InvalidClaimValue):
        submit_claims(ctx["property"]["property_code"], ObjectId(), ObjectId(),
                      {"objective_features": "not_a_list"})
