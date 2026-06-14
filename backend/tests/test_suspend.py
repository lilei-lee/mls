"""经纪人暂停(suspended)语义单测。

暂停 = 软限制:能登录/读/完成在途协作,但不能发起新业务(挂房源/带客申请/带看)。
踢出(banned)在 get_current_agent 已先 403,优先于暂停。
"""
from bson import ObjectId
from fastapi import HTTPException
from fastapi.testclient import TestClient
import pytest

import main
from database import db
from auth import get_unsuspended_agent


# ── 依赖单元 ──

def test_get_unsuspended_agent_allows_active():
    a = {"_id": ObjectId(), "status": "active"}
    assert get_unsuspended_agent(a) is a


def test_get_unsuspended_agent_blocks_suspended():
    with pytest.raises(HTTPException) as e:
        get_unsuspended_agent({"_id": ObjectId(), "status": "suspended"})
    assert e.value.status_code == 403
    assert "暂停" in e.value.detail


# ── 端到端:暂停经纪人发起新业务被拦,读放行 ──

@pytest.fixture
def client():
    return TestClient(main.app)


def _register(client, phone="13900011122"):
    client.post("/api/v1/auth/send-sms-code", json={"phone": phone})
    r = client.post("/api/v1/auth/register", json={
        "phone": phone, "code": "123456", "name": "暂测",
        "id_card": "130702199001011234", "store_name": "暂测门店", "password": "pw1234",
    })
    return r.json()["access_token"]


def test_suspended_blocked_from_showing_request(client):
    phone = "13900011133"
    token = _register(client, phone)
    db["agents"].update_one({"phone": phone}, {"$set": {"status": "suspended"}})
    H = {"Authorization": f"Bearer {token}"}
    r = client.post("/api/v1/showing-requests", json={
        "listing_id": str(ObjectId()), "customer_surname": "王", "customer_gender": "male",
        "requirements": "三室", "customer_id": str(ObjectId()),
    }, headers=H)
    assert r.status_code == 403
    assert "暂停" in r.json()["detail"]


def test_suspended_can_still_read_me(client):
    phone = "13900011144"
    token = _register(client, phone)
    db["agents"].update_one({"phone": phone}, {"$set": {"status": "suspended"}})
    H = {"Authorization": f"Bearer {token}"}
    r = client.get("/api/v1/me", headers=H)
    assert r.status_code == 200  # 暂停仍可登录/读
