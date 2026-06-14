"""scheduler.expire_stale_showing_requests 单测(带客申请 7 天过期定时任务)。

锁定已实现行为:每天 3:00 把超过 7 天未处理的 pending 申请批量改为 expired。
"""
from datetime import datetime, timedelta

from bson import ObjectId

from database import db
from scheduler import expire_stale_showing_requests


def _seed_req(created_at, status="pending"):
    return db["showing_requests"].insert_one({
        "listing_agent_id": ObjectId(), "buyer_agent_id": ObjectId(),
        "status": status, "created_at": created_at, "updated_at": created_at,
    }).inserted_id


def test_stale_pending_expired():
    """8 天前的 pending → expired,并写过期理由"""
    old = _seed_req(datetime.now() - timedelta(days=8))
    expire_stale_showing_requests()
    doc = db["showing_requests"].find_one({"_id": old})
    assert doc["status"] == "expired"
    assert doc["reject_reason"] == "expired"
    assert doc.get("reviewed_at") is not None


def test_recent_pending_untouched():
    """2 天前的 pending 不动(未满 7 天)"""
    recent = _seed_req(datetime.now() - timedelta(days=2))
    expire_stale_showing_requests()
    doc = db["showing_requests"].find_one({"_id": recent})
    assert doc["status"] == "pending"


def test_non_pending_untouched():
    """已审批的旧申请不动(只过期 pending 状态)"""
    approved = _seed_req(datetime.now() - timedelta(days=30), status="approved")
    expire_stale_showing_requests()
    doc = db["showing_requests"].find_one({"_id": approved})
    assert doc["status"] == "approved"
