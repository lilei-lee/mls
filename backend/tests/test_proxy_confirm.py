"""代确认成交单测(⚠️反作弊基石):B 模型 —— 独立填 + 比对照旧 + 前置守卫。"""
from datetime import datetime

from bson import ObjectId
import pytest
from fastapi import HTTPException

from database import db
from transactions import proxy_confirm_transaction


def _seed_tx(la_status="suspended", ba_price=800000, ba_date=datetime(2026, 5, 1), status="pending_la_confirm"):
    la_id = db["agents"].insert_one({"_id": ObjectId(), "name": "张三", "status": la_status}).inserted_id
    tx_id = db["transactions"].insert_one({
        "_id": ObjectId(), "status": status,
        "la_agent_id": la_id, "ba_agent_id": ObjectId(),
        "la_agent_name": "张三", "ba_agent_name": "李红",
        "ba_deal_price_yuan": ba_price, "ba_deal_date": ba_date,
        "la_deal_price_yuan": None, "la_deal_date": None,
        "listing_id": ObjectId(), "showing_id": ObjectId(),
        "listing_snapshot": {"community": "代确认小区"},
        "created_at": datetime.now(), "ba_submitted_at": datetime.now(),
        "reject_kind": None, "reject_reason": None,
    }).inserted_id
    return str(tx_id), la_id


# ── 前置守卫:LA 必须被暂停/踢出才可代确认 ──

def test_refuse_when_la_active():
    tx_id, _ = _seed_tx(la_status="active")
    with pytest.raises(HTTPException) as e:
        proxy_confirm_transaction(tx_id, 800000, "2026-05-01", "x")
    assert e.value.status_code == 400
    assert "暂停/踢出" in e.value.detail


def test_refuse_when_not_pending():
    tx_id, _ = _seed_tx(la_status="suspended", status="confirmed")
    with pytest.raises(HTTPException) as e:
        proxy_confirm_transaction(tx_id, 800000, "2026-05-01", "x")
    assert e.value.status_code == 400


# ── B 模型:比对照旧 ──

def test_match_confirms(  ):
    """LA 被暂停 + admin 填的值与 BA 分毫不差 → confirmed,且记 proxy 元数据"""
    tx_id, _ = _seed_tx(la_status="suspended", ba_price=800000, ba_date=datetime(2026, 5, 1))
    res = proxy_confirm_transaction(tx_id, 800000, "2026-05-01", "LA 已踢出,依据合同")
    assert res["status"] == "confirmed"
    t = db["transactions"].find_one({"_id": ObjectId(tx_id)})
    assert t["status"] == "confirmed"
    assert t["proxy_confirmed"] is True and t["proxy_by"] == "admin"
    assert t["la_deal_price_yuan"] == 800000


def test_mismatch_rejects_not_auto_pass():
    """admin 填的价 ≠ BA → 照样 rejected(反作弊:不会因为是 admin 就放行)"""
    tx_id, _ = _seed_tx(la_status="banned", ba_price=800000, ba_date=datetime(2026, 5, 1))
    res = proxy_confirm_transaction(tx_id, 790000, "2026-05-01", "x")
    assert res["status"] == "rejected"
    t = db["transactions"].find_one({"_id": ObjectId(tx_id)})
    assert t["status"] == "rejected" and t["reject_kind"] == "price_mismatch"
