"""段 7.4: showing_request 快照辞典富化单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from unittest.mock import patch, MagicMock
from bson import ObjectId

from database import db


@patch("dictionary_client.DictionaryClient")
def test_create_showing_request_snapshot_enriched(mock_client_class):
    """listing.property_code 存在 → 快照 area_sqm 从辞典补,不再是 None"""
    mock_client = MagicMock()
    mock_client.get_property.return_value = {
        "authoritative_attrs": {"area_sqm": 120.0, "rooms": 4},
    }
    mock_client_class.return_value = mock_client

    # seed listing with property_code
    lid = db["listings"].insert_one({
        "house_code": f"SR-TEST-{str(ObjectId())[-6:]}",
        "community": "测试小区", "building": "1", "unit": "1", "room_no": str(ObjectId())[-6:],
        "district": "桥东区", "property_code": "SNAPTEST123",
        "area_sqm": None, "floor": None, "total_floor": None,
        "rooms": None, "halls": None, "bathrooms": None,
        "layout": "", "orientation": "南", "price_wan": 80.0,
        "owner_agent_id": ObjectId(), "owner_agent_name": "LA", "owner_agent_phone": "138",
        "status": "on_sale", "photo_count": 0, "photos": [],
        "created_at": __import__("datetime").datetime.now(),
        "updated_at": __import__("datetime").datetime.now(),
    }).inserted_id

    # Agent docs
    ba = {"_id": ObjectId(), "name": "BA", "phone": "139"}
    la = {"_id": ObjectId(), "name": "LA", "phone": "138"}
    db["agents"].insert_one({"_id": ba["_id"], "phone": "139", "name": "BA"})
    db["agents"].insert_one({"_id": la["_id"], "phone": "138", "name": "LA"})

    # Create showing request
    from showing_requests import create_showing_request, CreateShowingRequestBody
    req = CreateShowingRequestBody(
        listing_id=str(lid),
        customer_surname="测", customer_gender="male",
        requirements="测试需求",
    )

    result = create_showing_request(req, ba)
    rid = result["request_id"]

    # Check snapshot
    sr = db["showing_requests"].find_one({"_id": ObjectId(rid)})
    snap = sr["listing_snapshot"]
    assert snap["area_sqm"] == 120.0  # enriched from dict
    assert snap["community"] == "测试小区"

    # cleanup
    db["showing_requests"].delete_one({"_id": ObjectId(rid)})
    db["listings"].delete_one({"_id": lid})
    db["agents"].delete_many({"phone": {"$in": ["139", "138"]}})
