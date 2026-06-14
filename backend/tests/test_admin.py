"""Web 管理后台第一片单测:管理员登录鉴权 + 看板 + 会员授予。

走 TestClient(in-process)+ mongomock,不需起真服务。管理员默认凭据
admin/admin123(config 默认,生产用 env 覆盖)。
"""
from datetime import datetime

import pytest
from fastapi.testclient import TestClient

import main
from admin_auth import COOKIE_NAME
from database import db


@pytest.fixture
def client():
    return TestClient(main.app)


def _login(client):
    return client.post(
        "/admin/login",
        data={"username": "admin", "password": "admin123"},
        follow_redirects=False,
    )


# ── 登录 ──

def test_login_page_renders(client):
    r = client.get("/admin/login")
    assert r.status_code == 200
    assert "登录" in r.text


def test_login_wrong_credentials(client):
    r = client.post("/admin/login",
                    data={"username": "admin", "password": "WRONG"},
                    follow_redirects=False)
    assert r.status_code == 401
    assert COOKIE_NAME not in r.cookies


def test_login_correct_sets_cookie(client):
    r = _login(client)
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/"
    assert COOKIE_NAME in r.cookies


# ── 鉴权守卫 ──

def test_dashboard_requires_auth(client):
    r = client.get("/admin/", follow_redirects=False)
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/login"


# ── 看板 ──

def test_dashboard_authed(client):
    _login(client)
    r = client.get("/admin/", follow_redirects=False)
    assert r.status_code == 200
    assert "数据看板" in r.text


# ── 会员开通(经纪人详情页) ──

def test_agent_membership_grant(client):
    aid = _seed_agent()
    _login(client)
    r = client.post(f"/admin/agents/{aid}/membership",
                    data={"days": "365"}, follow_redirects=False)
    assert r.status_code == 303
    a = db["agents"].find_one({"_id": aid})
    assert isinstance(a.get("membership_expires_at"), datetime)
    assert a["membership_expires_at"] > datetime.now()


# ── 经纪人管理 ──

def _seed_agent(name="张三", phone="13912345678"):
    from bson import ObjectId
    return db["agents"].insert_one({
        "_id": ObjectId(), "name": name, "phone": phone, "store_name": "测试门店",
        "role": "agent", "status": "active", "coop_verified": False,
        "created_at": datetime.now(),
    }).inserted_id


def test_agents_requires_auth(client):
    r = client.get("/admin/agents", follow_redirects=False)
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/login"


def test_agents_list_authed(client):
    _seed_agent()
    _login(client)
    r = client.get("/admin/agents", follow_redirects=False)
    assert r.status_code == 200
    assert "张三" in r.text
    assert "经纪人管理" in r.text


def test_agents_search_filter(client):
    _seed_agent(name="张三", phone="13900000001")
    _seed_agent(name="李红", phone="13900000002")
    _login(client)
    r = client.get("/admin/agents", params={"q": "李红"}, follow_redirects=False)
    assert "李红" in r.text and "张三" not in r.text


def test_agent_detail(client):
    aid = _seed_agent()
    db["listings"].insert_one({
        "owner_agent_id": aid, "community": "阳光小区", "building": "3",
        "room_no": "501", "price_wan": 95.0, "status": "on_sale", "created_at": datetime.now(),
    })
    _login(client)
    r = client.get(f"/admin/agents/{aid}", follow_redirects=False)
    assert r.status_code == 200
    assert "张三" in r.text
    assert "阳光小区" in r.text


def test_agent_coop_approve(client):
    aid = _seed_agent()
    _login(client)
    r = client.post(f"/admin/agents/{aid}/coop", data={"action": "approve"}, follow_redirects=False)
    assert r.status_code == 303
    a = db["agents"].find_one({"_id": aid})
    assert a["coop_verified"] is True
    assert isinstance(a.get("coop_reviewed_at"), datetime)


# ── 房源管理 ──

def _seed_listing(community="阳光小区", status="on_sale", district="桥东区", house_code="HC-001"):
    from bson import ObjectId
    return db["listings"].insert_one({
        "_id": ObjectId(), "house_code": house_code, "community": community,
        "building": "3", "unit": "1", "room_no": "501", "district": district,
        "price_wan": 95.0, "bonus_yuan": 3000, "status": status,
        "owner_agent_name": "张三", "owner_agent_phone": "13912345678",
        "created_at": datetime.now(),
    }).inserted_id


def test_listings_requires_auth(client):
    r = client.get("/admin/listings", follow_redirects=False)
    assert r.status_code == 303


def test_listings_list_and_filter(client):
    _seed_listing(community="阳光小区", district="桥东区")
    _seed_listing(community="月亮花园", district="桥西区", house_code="HC-002")
    _login(client)
    r = client.get("/admin/listings", follow_redirects=False)
    assert r.status_code == 200 and "阳光小区" in r.text and "月亮花园" in r.text
    r2 = client.get("/admin/listings", params={"district_f": "桥西区"}, follow_redirects=False)
    assert "月亮花园" in r2.text and "阳光小区" not in r2.text


def test_listing_detail(client):
    lid = _seed_listing()
    _login(client)
    r = client.get(f"/admin/listings/{lid}", follow_redirects=False)
    assert r.status_code == 200 and "阳光小区" in r.text and "HC-001" in r.text


def test_listing_offline_then_restore(client):
    lid = _seed_listing(status="on_sale")
    _login(client)
    r = client.post(f"/admin/listings/{lid}/offline", data={"reason": "照片不合规"}, follow_redirects=False)
    assert r.status_code == 303
    assert db["listings"].find_one({"_id": lid})["status"] == "offline"
    r2 = client.post(f"/admin/listings/{lid}/restore", follow_redirects=False)
    assert r2.status_code == 303
    assert db["listings"].find_one({"_id": lid})["status"] == "on_sale"


def test_listing_offline_guard_non_on_sale(client):
    """交易中房源不可被手动下架(状态守卫)"""
    lid = _seed_listing(status="deposit_paid")
    _login(client)
    client.post(f"/admin/listings/{lid}/offline", data={"reason": "x"}, follow_redirects=False)
    assert db["listings"].find_one({"_id": lid})["status"] == "deposit_paid"  # 未变


# ── 看板增强 ──

def test_dashboard_enhanced_sections(client):
    _seed_listing(community="阳光小区", district="桥东区")
    _login(client)
    r = client.get("/admin/", follow_redirects=False)
    assert r.status_code == 200
    assert "环比趋势" in r.text
    assert "区域分布" in r.text
    assert "门店维度" in r.text


# ── 审计日志 + 踢出/恢复 ──

def test_audit_requires_auth(client):
    r = client.get("/admin/audit", follow_redirects=False)
    assert r.status_code == 303


def test_membership_grant_writes_audit(client):
    aid = _seed_agent()
    _login(client)
    client.post(f"/admin/agents/{aid}/membership", data={"days": "365"}, follow_redirects=False)
    e = db["audit_log"].find_one({"action": "membership_grant", "target_id": str(aid)})
    assert e is not None and e["detail"]["days"] == 365
    r = client.get("/admin/audit", follow_redirects=False)
    assert r.status_code == 200 and "会员开通/续期" in r.text


def test_agent_ban_and_unban(client):
    aid = _seed_agent()
    _login(client)
    # 踢出
    r = client.post(f"/admin/agents/{aid}/ban", data={"reason": "严重违规"}, follow_redirects=False)
    assert r.status_code == 303
    a = db["agents"].find_one({"_id": aid})
    assert a["status"] == "banned" and a["status_reason"] == "严重违规"
    assert db["audit_log"].find_one({"action": "agent_ban", "target_id": str(aid)}) is not None
    # 恢复
    client.post(f"/admin/agents/{aid}/unban", follow_redirects=False)
    assert db["agents"].find_one({"_id": aid})["status"] == "active"
    assert db["audit_log"].find_one({"action": "agent_restore", "target_id": str(aid)}) is not None


def test_listing_offline_writes_audit(client):
    lid = _seed_listing(status="on_sale")
    _login(client)
    client.post(f"/admin/listings/{lid}/offline", data={"reason": "照片不合规"}, follow_redirects=False)
    e = db["audit_log"].find_one({"action": "listing_offline", "target_id": str(lid)})
    assert e is not None and e["detail"]["reason"] == "照片不合规"
