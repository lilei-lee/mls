"""Dashboard happy-path 单测 — 守护懒 import / 缺符号回归。

背景:0227acb 修了 routers/dashboard.py 的 `from qna` → `from routers.qna`
(函数级懒 import,import main 发现不了,只在调 /dashboard/todos 时 500)。
本文件直接调路由函数,即便空库也会执行到那两处懒 import(行 192/206),
把这类「跑到才炸」的 bug 在 pytest 阶段就拦住。
"""
from datetime import datetime

import pytest
from bson import ObjectId

from routers.dashboard import (
    api_dashboard_todos,
    dashboard_summary_api,
    api_dashboard_recent_events,
)


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "测试LA", "phone": "13800001111"}


# ═══════════════════════ todos ═══════════════════════

def test_todos_empty_db(agent):
    """空库也能正常返回 — 守护行 192 `from routers.qna` / 行 206 `from transactions` 懒 import"""
    res = api_dashboard_todos(current_agent=agent)
    assert res["success"] is True
    assert res["data"]["todos"] == []
    assert res["data"]["total"] == 0


def test_todos_with_pending_approval(agent):
    """有一条待审批申请 → todos 含 approval 项"""
    from database import db
    db["showing_requests"].insert_one({
        "listing_agent_id": agent["_id"],
        "status": "pending",
        "buyer_agent_name": "李红",
        "customer_surname": "王", "customer_gender": "male",
        "requirements": "三室南向",
        "listing_snapshot": {"community": "测试小区", "building": "1", "unit": "2", "room_no": "301"},
        "created_at": datetime.now(),
    })
    res = api_dashboard_todos(current_agent=agent)
    types = [t["type"] for t in res["data"]["todos"]]
    assert "approval" in types
    assert res["data"]["total"] >= 1


# ═══════════════════════ summary ═══════════════════════

def test_summary_empty_db(agent):
    """空库 summary 返回 8 个计数键,全 0 — 守护各 count_* 模块 import"""
    res = dashboard_summary_api(agent=agent)
    assert res["success"] is True
    data = res["data"]
    for key in (
        "my_on_sale_count", "shared_total_count", "shared_new_today_count",
        "pending_approval_count", "pending_confirm_showing_count",
        "pending_confirm_transaction_count", "pending_settlement_count",
        "my_sent_recent_changes_count",
    ):
        assert key in data
        assert data[key] == 0


# ═══════════════════════ recent-events ═══════════════════════

def test_recent_events_empty_db(agent):
    """空库 recent-events 返回空事件流"""
    res = api_dashboard_recent_events(current_agent=agent)
    assert res["success"] is True
    assert res["data"]["events"] == []
    assert res["data"]["total"] == 0
