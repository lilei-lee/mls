"""batch endpoint 单测"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from fastapi.testclient import TestClient
from datetime import datetime
from bson import ObjectId

from database import db
from main import app
from config import DICT_API_KEYS

client = TestClient(app)
VALID_KEY = next(iter(DICT_API_KEYS.keys()))
HEADERS = {"X-API-Key": VALID_KEY}


@pytest.fixture(scope="module")
def test_city():
    doc = {"name": "_TEST_BATCH_CITY_", "code": "TBC", "created_at": datetime.now()}
    result = db["cities"].insert_one(doc)
    yield result.inserted_id
    db["properties"].delete_many({"city_id": result.inserted_id})
    db["communities"].delete_many({"city_id": result.inserted_id})
    db["districts"].delete_many({"city_id": result.inserted_id})
    db["cities"].delete_one({"_id": result.inserted_id})


@pytest.fixture(scope="module")
def test_district(test_city):
    doc = {"city_id": test_city, "name": "_TEST_BATCH_DIST_", "created_at": datetime.now()}
    result = db["districts"].insert_one(doc)
    yield result.inserted_id


@pytest.fixture(scope="module")
def two_codes(test_city, test_district):
    """创建 2 个 property 返回其 code"""
    from services.community_service import get_or_create_community
    from services.property_service import get_or_create_property
    suffix = str(ObjectId())[-6:]
    c = get_or_create_community(test_city, test_district, f"Batch小区_{suffix}")
    p1 = get_or_create_property(test_city, test_district, c["_id"], "1", "1", suffix)
    p2 = get_or_create_property(test_city, test_district, c["_id"], "1", "2", suffix)
    return p1["property_code"], p2["property_code"]


def test_batch_happy(two_codes):
    c1, c2 = two_codes
    r = client.post("/v1/properties/batch", json={"codes": [c1, c2]}, headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert c1 in data and c2 in data
    assert data[c1] is not None
    assert data[c2] is not None
    assert data[c1]["property_code"] == c1


def test_batch_with_missing(two_codes):
    c1, _ = two_codes
    r = client.post("/v1/properties/batch", json={"codes": [c1, "NOTEXIST0000"]}, headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert data[c1] is not None
    assert data["NOTEXIST0000"] is None


def test_batch_too_long(two_codes):
    r = client.post("/v1/properties/batch", json={"codes": ["X" * 12] * 101}, headers=HEADERS)
    assert r.status_code == 422


def test_batch_no_key():
    r = client.post("/v1/properties/batch", json={"codes": ["XXXXXXXXXXXX"]})
    assert r.status_code == 401
