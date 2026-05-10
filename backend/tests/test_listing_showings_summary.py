"""V2.2 #3: GET /listings/{id}/showings-summary 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from datetime import datetime
from unittest.mock import patch, MagicMock
from bson import ObjectId


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "测试LA", "phone": "13800001111"}


@pytest.fixture
def ba_agent():
    return {"_id": ObjectId(), "name": "李红", "phone": "13200132000"}


def _seed_listing(owner_id, community="汇总测试小区"):
    from database import db
    return db["listings"].insert_one({
        "house_code": f"SUM-{str(ObjectId())[-6:]}",
        "community": community, "building": "1", "unit": "1", "room_no": "101",
        "district": "桥东区", "property_code": "SUMCODE",
        "layout": "3室1卫", "orientation": "南", "price_wan": 80.0,
        "status": "on_sale",
        "owner_agent_id": owner_id, "owner_agent_name": "测试LA", "owner_agent_phone": "138",
        "sale_points": [], "public_remarks": "", "agent_remarks": "",
        "showing_instructions": "", "photo_count": 0, "photos": [],
        "created_at": datetime.now(), "updated_at": datetime.now(),
        "bonus_yuan": 0, "cover_thumbnail": None,
    }).inserted_id


def _seed_sr(listing_id, ba_id, status="pending", ba_name="李红", ba_phone="13200132000",
             customer_surname="刘", customer_gender="male", requirements="三居室带电梯"):
    from database import db
    return db["showing_requests"].insert_one({
        "listing_id": listing_id, "buyer_agent_id": ba_id,
        "buyer_agent_name": ba_name, "buyer_agent_phone": ba_phone,
        "listing_agent_id": ObjectId(), "listing_agent_name": "LA",
        "customer_surname": customer_surname, "customer_gender": customer_gender,
        "requirements": requirements,
        "status": status, "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


def _seed_showing(request_id, status="confirmed"):
    from database import db
    return db["showings"].insert_one({
        "showing_request_id": request_id,
        "ba_agent_id": ObjectId(), "la_agent_id": ObjectId(),
        "listing_id": ObjectId(),
        "status": status, "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


def _seed_tx(showing_id, status="confirmed"):
    from database import db
    return db["transactions"].insert_one({
        "showing_id": showing_id, "listing_id": ObjectId(),
        "ba_agent_id": ObjectId(), "la_agent_id": ObjectId(),
        "status": status,
        "ba_deal_price_yuan": 800000, "ba_deal_date": "2026-05-01",
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


def _seed_ba(ba_id, name="李红", phone="13200132000"):
    from database import db
    db["agents"].insert_one({"_id": ba_id, "name": name, "phone": phone})


# ═══════════════════ Tests ═══════════════════

def test_owner_can_get_summary(agent):
    """LA owner 可以查到带看汇总"""
    from database import db
    from listings import get_showings_summary
    lid = _seed_listing(agent["_id"])
    sr_id = _seed_sr(lid, ObjectId())

    result = get_showings_summary(str(lid), agent["_id"])
    assert len(result) == 1
    assert result[0]["showing_request_id"] == str(sr_id)
    assert result[0]["current_status"] == "pending"
    assert result[0]["customer_name"] == "刘先生"

    db["showing_requests"].delete_many({"listing_id": lid})
    db["listings"].delete_one({"_id": lid})


def test_non_owner_returns_403(agent):
    """非 LA owner 调 → 403"""
    from database import db
    from listings import get_showings_summary
    from fastapi import HTTPException
    lid = _seed_listing(agent["_id"])
    other_id = ObjectId()

    with pytest.raises(HTTPException) as exc:
        get_showings_summary(str(lid), other_id)
    assert exc.value.status_code == 403

    db["listings"].delete_one({"_id": lid})


def test_summary_sorts_by_latest_event(agent):
    """按 latest_event_at 降序排列"""
    from database import db
    from listings import get_showings_summary
    lid = _seed_listing(agent["_id"])
    sr1 = _seed_sr(lid, ObjectId(), customer_surname="赵")
    sr2 = _seed_sr(lid, ObjectId(), customer_surname="钱")

    # 更新 sr1 的 updated_at 为更晚
    later = datetime(2026, 5, 15)
    db["showing_requests"].update_one({"_id": sr1}, {"$set": {"updated_at": later}})

    result = get_showings_summary(str(lid), agent["_id"])
    assert result[0]["customer_name"] == "赵先生"  # 最新在前

    db["showing_requests"].delete_many({"listing_id": lid})
    db["listings"].delete_one({"_id": lid})


def test_pending_status_hides_phone(agent, ba_agent):
    """pending 状态不返 BA 电话"""
    from database import db
    from listings import get_showings_summary
    _seed_ba(ba_agent["_id"], ba_agent["name"], ba_agent["phone"])
    lid = _seed_listing(agent["_id"])
    _seed_sr(lid, ba_agent["_id"], status="pending")

    result = get_showings_summary(str(lid), agent["_id"])
    assert result[0]["ba_phone"] is None

    db["agents"].delete_one({"_id": ba_agent["_id"]})
    db["showing_requests"].delete_many({"listing_id": lid})
    db["listings"].delete_one({"_id": lid})


def test_approved_status_returns_phone(agent, ba_agent):
    """approved 状态返 BA 电话"""
    from database import db
    from listings import get_showings_summary
    _seed_ba(ba_agent["_id"], ba_agent["name"], ba_agent["phone"])
    lid = _seed_listing(agent["_id"])
    _seed_sr(lid, ba_agent["_id"], status="approved")

    result = get_showings_summary(str(lid), agent["_id"])
    assert result[0]["ba_phone"] == "13200132000"

    db["agents"].delete_one({"_id": ba_agent["_id"]})
    db["showing_requests"].delete_many({"listing_id": lid})
    db["listings"].delete_one({"_id": lid})


def test_status_label_matches_lifecycle(agent):
    """状态标签覆盖全部 7 种生命周期"""
    from database import db
    from listings import get_showings_summary, _SR_STATUS_LABEL
    lid = _seed_listing(agent["_id"])
    ba = ObjectId()

    sr = _seed_sr(lid, ba, status="pending")
    r = get_showings_summary(str(lid), agent["_id"])
    assert r[0]["current_status_label"] == "申请中"
    db["showing_requests"].delete_one({"_id": sr})

    sr = _seed_sr(lid, ba, status="approved")
    r = get_showings_summary(str(lid), agent["_id"])
    assert r[0]["current_status_label"] == "已通过"
    db["showing_requests"].delete_one({"_id": sr})

    sr = _seed_sr(lid, ba, status="approved")
    sh = _seed_showing(sr, status="confirmed")
    r = get_showings_summary(str(lid), agent["_id"])
    assert r[0]["current_status_label"] == "已带看"
    db["showings"].delete_one({"_id": sh})
    db["showing_requests"].delete_one({"_id": sr})

    sr = _seed_sr(lid, ba, status="approved")
    sh = _seed_showing(sr, status="confirmed")
    tx = _seed_tx(sh, status="pending_la_confirm")
    r = get_showings_summary(str(lid), agent["_id"])
    assert r[0]["current_status_label"] == "已发起成交"
    db["transactions"].delete_one({"_id": tx})
    db["showings"].delete_one({"_id": sh})
    db["showing_requests"].delete_one({"_id": sr})

    sr = _seed_sr(lid, ba, status="rejected")
    r = get_showings_summary(str(lid), agent["_id"])
    assert r[0]["current_status_label"] == "已拒绝"
    db["showing_requests"].delete_one({"_id": sr})

    db["listings"].delete_one({"_id": lid})


def test_empty_listing_returns_empty_array(agent):
    """没有带看记录时返空数组"""
    from database import db
    from listings import get_showings_summary
    lid = _seed_listing(agent["_id"])
    result = get_showings_summary(str(lid), agent["_id"])
    assert result == []
    db["listings"].delete_one({"_id": lid})
