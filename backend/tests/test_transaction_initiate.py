"""initiate_transaction 单测:日期按天比较 + bonus_yuan 快照。

锁定已实现行为(Day17 后修/做,此前无测试守护):
- 成交日期 vs 带看时间按"天"截断比较 → 同天带看同天成交不被拦
- 发起成交时把 listing 当前 bonus_yuan 拍快照,金额锁定在 BA 提交时点
"""
from datetime import datetime, timedelta

import pytest
from bson import ObjectId
from fastapi import HTTPException

from database import db
from transactions import initiate_transaction, InitiateTransactionBody


@pytest.fixture
def la_agent():
    return {"_id": ObjectId(), "name": "张三", "phone": "138"}


@pytest.fixture
def ba_agent():
    return {"_id": ObjectId(), "name": "李红", "phone": "139"}


def _seed_listing_and_showing(la, ba, *, showing_time, bonus_yuan=0):
    lid = db["listings"].insert_one({
        "community": "测试小区", "building": "1", "unit": "1", "room_no": "101",
        "district": "桥东区", "property_code": "TX-PROP-1",
        "price_wan": 80.0, "bonus_yuan": bonus_yuan,
        "status": "deposit_paid",
        "owner_agent_id": la["_id"], "owner_agent_name": la["name"],
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id
    sid = db["showings"].insert_one({
        "showing_request_id": ObjectId(),
        "listing_id": lid,
        "ba_agent_id": ba["_id"], "ba_agent_name": ba["name"], "ba_agent_phone": ba["phone"],
        "la_agent_id": la["_id"], "la_agent_name": la["name"],
        "status": "confirmed",
        "showing_time": showing_time,
        "listing_snapshot": {"community": "测试小区", "building": "1", "unit": "1", "room_no": "101"},
        "created_at": datetime.now(),
    }).inserted_id
    return lid, sid


def _body(sid, deal_date, price=800000):
    return InitiateTransactionBody(
        showing_id=str(sid), deal_price_yuan=price, deal_date=deal_date, notes="t")


# ── 日期按天比较 ──

def test_same_day_showing_and_deal_allowed(la_agent, ba_agent):
    """同天带看同天成交应放行(按天截断,不按时刻严格比较)"""
    _, sid = _seed_listing_and_showing(la_agent, ba_agent, showing_time=datetime(2026, 3, 10, 14, 30))
    res = initiate_transaction(_body(sid, "2026-03-10"), ba_agent)
    assert "transaction_id" in res


def test_deal_before_showing_rejected(la_agent, ba_agent):
    _, sid = _seed_listing_and_showing(la_agent, ba_agent, showing_time=datetime(2026, 3, 10, 14, 30))
    with pytest.raises(HTTPException) as e:
        initiate_transaction(_body(sid, "2026-03-09"), ba_agent)
    assert e.value.status_code == 400
    assert "早于带看" in str(e.value.detail)


def test_future_deal_rejected(la_agent, ba_agent):
    _, sid = _seed_listing_and_showing(la_agent, ba_agent, showing_time=datetime.now() - timedelta(days=1))
    future = (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%d")
    with pytest.raises(HTTPException) as e:
        initiate_transaction(_body(sid, future), ba_agent)
    assert e.value.status_code == 400
    assert "晚于今天" in str(e.value.detail)


# ── bonus_yuan 快照 ──

def test_bonus_snapshot_stored_at_initiate(la_agent, ba_agent):
    """发起成交时把 listing 当前 bonus_yuan 拍快照存进 tx"""
    _, sid = _seed_listing_and_showing(la_agent, ba_agent, showing_time=datetime(2026, 3, 10), bonus_yuan=5000)
    res = initiate_transaction(_body(sid, "2026-03-10"), ba_agent)
    tx = db["transactions"].find_one({"_id": ObjectId(res["transaction_id"])})
    assert tx["bonus_yuan_snapshot"] == 5000


def test_bonus_snapshot_immune_to_later_listing_change(la_agent, ba_agent):
    """发起后改 listing.bonus_yuan,快照不变(金额锁定在 BA 提交时点)"""
    lid, sid = _seed_listing_and_showing(la_agent, ba_agent, showing_time=datetime(2026, 3, 10), bonus_yuan=5000)
    res = initiate_transaction(_body(sid, "2026-03-10"), ba_agent)
    db["listings"].update_one({"_id": lid}, {"$set": {"bonus_yuan": 9000}})
    tx = db["transactions"].find_one({"_id": ObjectId(res["transaction_id"])})
    assert tx["bonus_yuan_snapshot"] == 5000  # 不受后续改动影响
