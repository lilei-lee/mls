"""段 7.5.2: sync-physical endpoint 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from unittest.mock import patch, MagicMock
from bson import ObjectId
from listings import DICT_PHYSICAL_FIELDS


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "SyncLA", "phone": "138"}


def _seed_listing(owner_id, property_code="SYNCPROPCODE"):
    from database import db
    from datetime import datetime
    return db["listings"].insert_one({
        "house_code": f"SYNC-{str(ObjectId())[-6:]}",
        "community": "同步测试", "building": "1", "unit": "1", "room_no": str(ObjectId())[-6:],
        "district": "桥东区", "property_code": property_code,
        "orientation": "南", "price_wan": 80.0, "status": "on_sale",
        "owner_agent_id": owner_id, "owner_agent_name": "SyncLA", "owner_agent_phone": "138",
        "layout": "", "photo_count": 0, "photos": [],
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_happy(mock_cls, agent):
    """authoritative_attrs 完整 → 提交 claim 成功"""
    lid = _seed_listing(agent["_id"])
    mock = MagicMock()
    mock.get_property.return_value = {
        "authoritative_attrs": {"area_sqm": 120.0, "floor": 8, "rooms": 3},
    }
    mock.submit_claim.return_value = {"total_claims_after": 2}
    mock_cls.return_value = mock

    from listings import sync_physical_to_dict, SyncPhysicalBody
    body = SyncPhysicalBody()
    r = sync_physical_to_dict(str(lid), body, agent["_id"])
    assert r["synced_fields"] == ["area_sqm", "floor", "rooms"]
    assert r["synced_values"]["area_sqm"] == 120.0
    assert r["listing_id"] == str(lid)
    # verify submit_claim was called
    assert mock.submit_claim.call_count == 1

    from database import db
    db["listings"].delete_one({"_id": lid})


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_not_owner(mock_cls, agent):
    """viewer_id != owner → 403"""
    lid = _seed_listing(agent["_id"])
    other = ObjectId()

    from listings import sync_physical_to_dict, SyncPhysicalBody
    from fastapi import HTTPException
    body = SyncPhysicalBody()
    with pytest.raises(HTTPException) as exc:
        sync_physical_to_dict(str(lid), body, other)
    assert exc.value.status_code == 403

    from database import db
    db["listings"].delete_one({"_id": lid})


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_no_property_code(mock_cls, agent):
    """listing.property_code=None → 400"""
    lid = _seed_listing(agent["_id"], property_code=None)

    from listings import sync_physical_to_dict, SyncPhysicalBody
    from fastapi import HTTPException
    body = SyncPhysicalBody()
    with pytest.raises(HTTPException) as exc:
        sync_physical_to_dict(str(lid), body, agent["_id"])
    assert exc.value.status_code == 400

    from database import db
    db["listings"].delete_one({"_id": lid})


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_no_authoritative(mock_cls, agent):
    """authoritative_attrs 为空 → 400"""
    lid = _seed_listing(agent["_id"])
    mock = MagicMock()
    mock.get_property.return_value = {"authoritative_attrs": {}}
    mock_cls.return_value = mock

    from listings import sync_physical_to_dict, SyncPhysicalBody
    from fastapi import HTTPException
    body = SyncPhysicalBody()
    with pytest.raises(HTTPException) as exc:
        sync_physical_to_dict(str(lid), body, agent["_id"])
    assert exc.value.status_code == 400

    from database import db
    db["listings"].delete_one({"_id": lid})


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_dict_unavailable(mock_cls, agent):
    """submit_claim 抛 Unavailable → 503"""
    from dictionary_client import DictionaryUnavailableError
    lid = _seed_listing(agent["_id"])
    mock = MagicMock()
    mock.get_property.return_value = {
        "authoritative_attrs": {"area_sqm": 120.0},
    }
    mock.submit_claim.side_effect = DictionaryUnavailableError("down")
    mock_cls.return_value = mock

    from listings import sync_physical_to_dict, SyncPhysicalBody
    from fastapi import HTTPException
    body = SyncPhysicalBody()
    with pytest.raises(HTTPException) as exc:
        sync_physical_to_dict(str(lid), body, agent["_id"])
    assert exc.value.status_code == 503

    from database import db
    db["listings"].delete_one({"_id": lid})
