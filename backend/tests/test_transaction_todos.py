"""Day 37: 成交双向待办 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from bson import ObjectId
from datetime import datetime
from database import db


@pytest.fixture
def la_agent():
    return {"_id": ObjectId(), "name": "张三"}

@pytest.fixture
def ba_agent():
    return {"_id": ObjectId(), "name": "李红"}

def _seed_tx(la_id, ba_id, status="pending_la_confirm"):
    return db["transactions"].insert_one({
        "la_agent_id": la_id, "ba_agent_id": ba_id,
        "showing_id": ObjectId(), "listing_id": ObjectId(),
        "status": status,
        "ba_deal_price_yuan": 800000, "ba_deal_date": "2026-05-01",
        "ba_submitted_at": datetime.now(),
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


# ═══════════════════ Tests ═══════════════════

def test_la_count_0_when_no_tx(la_agent):
    from transactions import _count_la_pending_transactions
    assert _count_la_pending_transactions(la_agent["_id"]) == 0


def test_ba_count_0_when_no_tx(ba_agent):
    from transactions import _count_ba_waiting_transactions
    assert _count_ba_waiting_transactions(ba_agent["_id"]) == 0


def test_la_count_matches_pending(la_agent, ba_agent):
    from transactions import _count_la_pending_transactions
    for _ in range(3):
        _seed_tx(la_agent["_id"], ba_agent["_id"])
    assert _count_la_pending_transactions(la_agent["_id"]) == 3
    db["transactions"].delete_many({"la_agent_id": la_agent["_id"]})


def test_ba_count_matches_pending(la_agent, ba_agent):
    from transactions import _count_ba_waiting_transactions
    for _ in range(2):
        _seed_tx(la_agent["_id"], ba_agent["_id"])
    assert _count_ba_waiting_transactions(ba_agent["_id"]) == 2
    db["transactions"].delete_many({"la_agent_id": la_agent["_id"]})


def test_count_functions_consistent(la_agent, ba_agent):
    """两个公共函数对同一笔 tx 返回正确计数(LA+BA 各自视角)"""
    from transactions import _count_la_pending_transactions, _count_ba_waiting_transactions
    _seed_tx(la_agent["_id"], ba_agent["_id"])
    assert _count_la_pending_transactions(la_agent["_id"]) == 1
    assert _count_ba_waiting_transactions(ba_agent["_id"]) == 1
    db["transactions"].delete_many({"la_agent_id": la_agent["_id"]})


def test_completed_tx_not_counted(la_agent, ba_agent):
    """confirmed/rejected/cancelled 不计入待办"""
    from transactions import _count_la_pending_transactions
    _seed_tx(la_agent["_id"], ba_agent["_id"], status="confirmed")
    _seed_tx(la_agent["_id"], ba_agent["_id"], status="rejected")
    _seed_tx(la_agent["_id"], ba_agent["_id"], status="cancelled")
    _seed_tx(la_agent["_id"], ba_agent["_id"], status="pending_la_confirm")
    assert _count_la_pending_transactions(la_agent["_id"]) == 1
    db["transactions"].delete_many({"la_agent_id": la_agent["_id"]})
