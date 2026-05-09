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
    oid = r.inserted_id
    yield oid
    db["properties"].delete_many({"city_id": oid})
    db["communities"].delete_many({"city_id": oid})
    db["districts"].delete_many({"city_id": oid})
    db["cities"].delete_one({"_id": oid})

@pytest.fixture
def test_district(test_city):
    doc = {"city_id": test_city, "name": f"_V22D_{ObjectId()}", "created_at": datetime.now()}
    yield db["districts"].insert_one(doc).inserted_id

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


# ── Community batch endpoint ──

def test_community_batch_endpoint(ctx):
    from fastapi.testclient import TestClient
    from main import app
    from config import DICT_API_KEYS
    client = TestClient(app)
    headers = {"X-API-Key": next(iter(DICT_API_KEYS.keys()))}
    cid1 = str(ctx["community"]["_id"])
    # 再建第二个小区
    from services.community_service import get_or_create_community
    c2 = get_or_create_community(ctx["city"], ctx["district"], f"V22_batch_{str(ObjectId())[-4:]}")
    cid2 = str(c2["_id"])
    # 正常返多条
    r = client.post("/v1/communities/batch", json={"community_ids": [cid1, cid2]}, headers=headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    ids = [d["_id"] for d in data]
    assert cid1 in ids
    assert cid2 in ids
    # 空数组:min_length=1 → 422
    r2 = client.post("/v1/communities/batch", json={"community_ids": []}, headers=headers)
    assert r2.status_code == 422
    # 不存在的 id:静默跳过,不在结果中
    fake_id = str(ObjectId())
    r3 = client.post("/v1/communities/batch", json={"community_ids": [cid1, fake_id]}, headers=headers)
    assert r3.status_code == 200
    ids3 = [d["_id"] for d in r3.json()]
    assert cid1 in ids3
    assert fake_id not in ids3


# ── Discrepancy 自动生成 ──

def test_property_objective_features_claim_with_discrepancy(ctx):
    from services.claim_service import submit_claims
    from services.comparison import list_pending_discrepancies
    # 第一次 claim:first_claim,无 discrepancy
    r1 = submit_claims(ctx["property"]["property_code"], ObjectId(), ObjectId(),
                       {"objective_features": ["南北通透", "全明格局"]})
    assert r1["total_claims_after"] >= 1
    for cr in r1["comparison_results"]:
        if cr["field"] == "objective_features":
            assert cr["consensus"] == "first_claim"
            assert cr["discrepancy_id"] is None
    # 第二次 claim:不同值 → differs + 生 discrepancy
    r2 = submit_claims(ctx["property"]["property_code"], ObjectId(), ObjectId(),
                       {"objective_features": ["客厅朝南"]})
    assert r2["total_claims_after"] >= 2
    disc_id = None
    for cr in r2["comparison_results"]:
        if cr["field"] == "objective_features":
            assert cr["consensus"] == "differs"
            disc_id = cr["discrepancy_id"]
            assert disc_id is not None
    # 确认 discrepancy 工单落库
    assert disc_id is not None
    from services.comparison import get_discrepancy_by_id
    disc = get_discrepancy_by_id(disc_id)
    assert disc is not None
    assert disc["field"] == "objective_features"
    assert disc["status"] == "pending"
    assert disc["new_value"] == ["客厅朝南"]
