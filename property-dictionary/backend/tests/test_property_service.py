import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime
from bson import ObjectId

from database import db
from services.community_service import (
    get_or_create_community, get_community_by_code,
    list_communities_by_city,
)
from services.property_service import (
    get_or_create_property, get_property_by_code, get_property_by_address,
)
from services.exceptions import (
    CityNotFound, DistrictNotFound, CommunityNotFound,
    InvalidIdentifier, PropertyNotFound,
)


@pytest.fixture(scope="module")
def test_city():
    doc = {"name": "_TEST_CITY_", "code": "TST", "created_at": datetime.now()}
    result = db["cities"].insert_one(doc)
    yield result.inserted_id
    db["properties"].delete_many({"city_id": result.inserted_id})
    db["communities"].delete_many({"city_id": result.inserted_id})
    db["districts"].delete_many({"city_id": result.inserted_id})
    db["cities"].delete_one({"_id": result.inserted_id})


@pytest.fixture(scope="module")
def test_district(test_city):
    doc = {"city_id": test_city, "name": "_TEST_DISTRICT_", "created_at": datetime.now()}
    result = db["districts"].insert_one(doc)
    yield result.inserted_id


# ============ Community ============

def test_create_community(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "测试小区A")
    assert c["name"] == "测试小区A"
    assert len(c["community_code"]) == 12
    assert c["authoritative_attrs"] == {}

def test_idempotent_community(test_city, test_district):
    c1 = get_or_create_community(test_city, test_district, "测试小区B")
    c2 = get_or_create_community(test_city, test_district, "测试小区B")
    assert c1["_id"] == c2["_id"]
    assert c1["community_code"] == c2["community_code"]

def test_community_name_strip(test_city, test_district):
    c1 = get_or_create_community(test_city, test_district, "测试小区C")
    c2 = get_or_create_community(test_city, test_district, "  测试小区C  ")
    assert c1["_id"] == c2["_id"]

def test_community_invalid_district(test_city):
    with pytest.raises(DistrictNotFound):
        get_or_create_community(test_city, ObjectId(), "测试小区Z")

def test_community_empty_name(test_city, test_district):
    with pytest.raises(InvalidIdentifier):
        get_or_create_community(test_city, test_district, "  ")

def test_get_community_by_code(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "测试小区D")
    found = get_community_by_code(c["community_code"])
    assert found["_id"] == c["_id"]

def test_list_communities(test_city, test_district):
    get_or_create_community(test_city, test_district, "搜索测试小区1")
    get_or_create_community(test_city, test_district, "搜索测试小区2")
    results = list_communities_by_city(test_city, name_keyword="搜索测试")
    names = [r["name"] for r in results]
    assert "搜索测试小区1" in names
    assert "搜索测试小区2" in names


# ============ Property ============

def test_create_property(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区A")
    p = get_or_create_property(test_city, test_district, c["_id"], "3", "1", "502")
    assert p["building"] == "3" and p["unit"] == "1" and p["room_no"] == "502"
    assert len(p["property_code"]) == 12
    assert p["authoritative_attrs"] == {}
    assert p["transaction_history"] == []

def test_idempotent_property(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区B")
    p1 = get_or_create_property(test_city, test_district, c["_id"], "3", "1", "502")
    p2 = get_or_create_property(test_city, test_district, c["_id"], "3", "1", "502")
    assert p1["_id"] == p2["_id"]

def test_different_address_different_property(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区C")
    p1 = get_or_create_property(test_city, test_district, c["_id"], "3", "1", "502")
    p2 = get_or_create_property(test_city, test_district, c["_id"], "3", "1", "503")
    assert p1["_id"] != p2["_id"]

def test_property_field_strip(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区D")
    p1 = get_or_create_property(test_city, test_district, c["_id"], "3", "1", "502")
    p2 = get_or_create_property(test_city, test_district, c["_id"], " 3 ", " 1 ", " 502 ")
    assert p1["_id"] == p2["_id"]

def test_property_empty_field(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区E")
    with pytest.raises(InvalidIdentifier):
        get_or_create_property(test_city, test_district, c["_id"], "3", "1", "")

def test_get_property_by_code(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区F")
    p = get_or_create_property(test_city, test_district, c["_id"], "5", "2", "1001")
    found = get_property_by_code(p["property_code"])
    assert found["_id"] == p["_id"]

def test_get_property_by_address_existing(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区G")
    p = get_or_create_property(test_city, test_district, c["_id"], "5", "2", "1001")
    found = get_property_by_address(test_city, test_district, c["_id"], "5", "2", "1001")
    assert found["_id"] == p["_id"]

def test_get_property_by_address_missing(test_city, test_district):
    c = get_or_create_community(test_city, test_district, "P测试小区H")
    found = get_property_by_address(test_city, test_district, c["_id"], "99", "99", "9999")
    assert found is None
