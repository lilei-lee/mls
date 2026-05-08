"""段 7.6: transaction sink 钩子 + 快照 property_code 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime
from bson import ObjectId

from database import db


# ── sink_transaction_to_dict 单测 ──

def test_sink_synced_happy():
    """辞典正常 → 返 'synced'"""
    from transactions import sink_transaction_to_dict

    tx = {
        "_id": ObjectId(), "listing_id": ObjectId(),
        "la_deal_price_yuan": 6100000,
        "la_deal_date": datetime(2026, 5, 6),
    }
    listing = {"property_code": "SYNCTEST1234"}

    with patch("dictionary_client.DictionaryClient") as mock_cls:
        mock_cls.return_value.sink_transaction.return_value = {"added": True}
        status = sink_transaction_to_dict(tx, listing)
    assert status == "synced"


def test_sink_no_property_code():
    """listing.property_code=None → 返 'no_property_code'，不调辞典"""
    from transactions import sink_transaction_to_dict

    tx = {"_id": ObjectId(), "listing_id": ObjectId(),
          "la_deal_price_yuan": 6000000, "la_deal_date": datetime(2026, 5, 6)}

    with patch("dictionary_client.DictionaryClient") as mock_cls:
        status = sink_transaction_to_dict(tx, None)
    assert status == "no_property_code"
    mock_cls.assert_not_called()


def test_sink_unavailable_queued():
    """辞典不可达 → 返 'queued', pending_dict_sinks 多 1 条"""
    from transactions import sink_transaction_to_dict
    from dictionary_client import DictionaryUnavailableError

    tx = {
        "_id": ObjectId(), "listing_id": ObjectId(),
        "la_deal_price_yuan": 6100000,
        "la_deal_date": datetime(2026, 5, 7),
        "ba_agent_id": ObjectId(),
        "la_agent_id": ObjectId(),
    }
    listing = {"property_code": "QUEUETEST12"}

    before = db["pending_dict_sinks"].count_documents({})
    with patch("dictionary_client.DictionaryClient") as mock_cls:
        mock_cls.return_value.sink_transaction.side_effect = DictionaryUnavailableError("down")
        status = sink_transaction_to_dict(tx, listing)
    assert status == "queued"
    assert db["pending_dict_sinks"].count_documents({}) == before + 1

    # cleanup
    db["pending_dict_sinks"].delete_many({"property_code": "QUEUETEST12"})


def test_sink_does_not_block_confirmed():
    """辞典抛异常 → 无论什么错 sink 都返 queued/no_code，不抛出去"""
    from transactions import sink_transaction_to_dict
    from dictionary_client import DictionaryForbiddenError

    tx = {
        "_id": ObjectId(), "listing_id": ObjectId(),
        "la_deal_price_yuan": 6100000,
        "la_deal_date": datetime(2026, 5, 6),
    }
    listing = {"property_code": "BLOCKTEST12"}

    with patch("dictionary_client.DictionaryClient") as mock_cls:
        mock_cls.return_value.sink_transaction.side_effect = DictionaryForbiddenError("bad config")
        status = sink_transaction_to_dict(tx, listing)

    assert status in ("queued", "no_property_code")

    # cleanup
    db["pending_dict_sinks"].delete_many({"property_code": "BLOCKTEST12"})


# ── initiate_transaction snapshot 单测 ──

def test_initiate_transaction_snapshot_includes_property_code():
    """initiate_transaction 创建时快照含 property_code"""
    from transactions import initiate_transaction, InitiateTransactionBody

    # seed data
    la = db["agents"].insert_one({"phone": "19900000001", "name": "SinkLA"}).inserted_id
    ba = db["agents"].insert_one({"phone": "19900000002", "name": "SinkBA"}).inserted_id
    listing_id = db["listings"].insert_one({
        "community": "Sink测试", "building": "1", "unit": "1", "room_no": "888",
        "district": "桥东区", "property_code": "SINKPROPCODE",
        "orientation": "南", "price_wan": 80.0, "status": "deposit_paid",
        "bonus_yuan": 0, "photo_count": 0, "photos": [],
        "owner_agent_id": la, "owner_agent_name": "SinkLA", "owner_agent_phone": "199",
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id
    showing_id = db["showings"].insert_one({
        "listing_id": listing_id, "showing_request_id": ObjectId(),
        "ba_agent_id": ba, "la_agent_id": la,
        "ba_agent_name": "SinkBA", "la_agent_name": "SinkLA",
        "status": "confirmed",
        "showing_time": datetime(2026, 5, 1, 10, 0),
        "listing_snapshot": {"community": "Sink测试", "price_wan": 80.0},
        "created_at": datetime.now(),
    }).inserted_id

    body = InitiateTransactionBody(
        showing_id=str(showing_id),
        deal_price_yuan=6100000,
        deal_date="2026-05-01",
    )
    ba_agent = {"_id": ba, "name": "SinkBA", "phone": "19900000002"}

    result = initiate_transaction(body, ba_agent)
    tx = db["transactions"].find_one({"_id": ObjectId(result["transaction_id"])})
    assert tx["listing_snapshot"].get("property_code") == "SINKPROPCODE"

    # cleanup
    db["transactions"].delete_one({"_id": tx["_id"]})
    db["showings"].delete_one({"_id": showing_id})
    db["listings"].delete_one({"_id": listing_id})
    db["agents"].delete_many({"phone": {"$regex": "^199"}})
