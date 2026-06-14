"""多管理员 + 角色权限(RBAC)单测:权限隔离、操作归属到人、账号管理、登录日志。"""
from datetime import datetime

import pytest
from fastapi.testclient import TestClient

import main
import admin_users
from database import db


@pytest.fixture
def client():
    return TestClient(main.app)


def _seed_admin(username, role, password="pass123"):
    admin_users.ensure_seed_admin()
    res = admin_users.create_admin(username, username, password, role, by="test")
    assert res["ok"], res["msg"]


def _login_as(client, username, password):
    return client.post("/admin/login",
                       data={"username": username, "password": password},
                       follow_redirects=False)


def _seed_listing(community="阳光小区", status="on_sale", house_code="HC-R1"):
    from bson import ObjectId
    return db["listings"].insert_one({
        "_id": ObjectId(), "house_code": house_code, "community": community,
        "building": "3", "unit": "1", "room_no": "501", "district": "桥东区",
        "price_wan": 95.0, "bonus_yuan": 3000, "status": status,
        "owner_agent_name": "张三", "owner_agent_phone": "13912345678",
        "created_at": datetime.now(),
    }).inserted_id


# ── 种子超管 ──

def test_seed_superadmin_login(client):
    r = _login_as(client, "admin", "admin123")
    assert r.status_code == 303 and r.headers["location"] == "/admin/"


def test_disabled_admin_cannot_login(client):
    _seed_admin("bob", "operator")
    admin_users.admin_users_collection.update_one({"username": "bob"}, {"$set": {"status": "disabled"}})
    r = _login_as(client, "bob", "pass123")
    assert r.status_code == 401


# ── 权限隔离 ──

def test_support_denied_listings(client):
    _seed_admin("kefu", "support")
    _login_as(client, "kefu", "pass123")
    r = client.get("/admin/listings", follow_redirects=False)
    assert r.status_code == 303 and "/admin/denied" in r.headers["location"]


def test_support_allowed_agents(client):
    _seed_admin("kefu", "support")
    _login_as(client, "kefu", "pass123")
    r = client.get("/admin/agents", follow_redirects=False)
    assert r.status_code == 200


def test_operator_denied_admins_page(client):
    _seed_admin("yunying", "operator")
    _login_as(client, "yunying", "pass123")
    r = client.get("/admin/admins", follow_redirects=False)
    assert r.status_code == 303 and "/admin/denied" in r.headers["location"]


def test_superadmin_reaches_admins_page(client):
    _login_as(client, "admin", "admin123")
    r = client.get("/admin/admins", follow_redirects=False)
    assert r.status_code == 200 and "管理员账号" in r.text


def test_nav_filtered_by_role(client):
    _seed_admin("kefu", "support")
    _login_as(client, "kefu", "pass123")
    r = client.get("/admin/", follow_redirects=False)
    assert r.status_code == 200
    # 客服能看经纪人,看不到房源/系统配置导航
    assert 'href="/admin/agents"' in r.text
    assert 'href="/admin/listings"' not in r.text
    assert 'href="/admin/config"' not in r.text


# ── 操作归属到人(审计 actor) ──

def test_audit_actor_is_acting_admin(client):
    _seed_admin("alice", "operator")
    _login_as(client, "alice", "pass123")
    lid = _seed_listing(status="on_sale")
    r = client.post(f"/admin/listings/{lid}/offline", data={"reason": "测试"}, follow_redirects=False)
    assert r.status_code == 303
    e = db["audit_log"].find_one({"action": "listing_offline", "target_id": str(lid)})
    assert e is not None and e["actor"] == "alice"  # 归到具体的人,不再是泛 admin


# ── 管理员账号管理 ──

def test_create_admin_and_change_role(client):
    _login_as(client, "admin", "admin123")
    r = client.post("/admin/admins", data={
        "username": "newop", "name": "小新", "password": "secret1", "role": "operator",
    }, follow_redirects=False)
    assert r.status_code == 303
    a = admin_users.admin_users_collection.find_one({"username": "newop"})
    assert a is not None and a["role"] == "operator"
    # 改角色
    aid = str(a["_id"])
    client.post(f"/admin/admins/{aid}/role", data={"role": "auditor"}, follow_redirects=False)
    assert admin_users.admin_users_collection.find_one({"username": "newop"})["role"] == "auditor"
    assert db["audit_log"].find_one({"action": "admin_create", "target_id": "newop"}) is not None


def test_cannot_disable_last_superadmin(client):
    _login_as(client, "admin", "admin123")
    sa = admin_users.admin_users_collection.find_one({"username": "admin"})
    # 直接调用服务层(避开"不能停用自己"的前置守卫,验证"最后一个超管"护栏)
    res = admin_users.set_status(str(sa["_id"]), "disabled")
    assert res["ok"] is False and "超级管理员" in res["msg"]


def test_cannot_disable_self_via_route(client):
    _login_as(client, "admin", "admin123")
    sa = admin_users.admin_users_collection.find_one({"username": "admin"})
    r = client.post(f"/admin/admins/{sa['_id']}/status",
                    data={"status_to": "disabled"}, follow_redirects=False)
    assert r.status_code == 303
    assert admin_users.admin_users_collection.find_one({"username": "admin"})["status"] == "active"


def test_reset_password(client):
    _seed_admin("toreset", "support", password="oldpass")
    _login_as(client, "admin", "admin123")
    a = admin_users.admin_users_collection.find_one({"username": "toreset"})
    client.post(f"/admin/admins/{a['_id']}/reset-password",
                data={"new_password": "brandnew1"}, follow_redirects=False)
    # 新密码能登录,旧的不行
    assert _login_as(client, "toreset", "brandnew1").status_code == 303
    assert _login_as(client, "toreset", "oldpass").status_code == 401


def test_create_admin_duplicate_rejected(client):
    _seed_admin("dup", "operator")
    _login_as(client, "admin", "admin123")
    r = client.post("/admin/admins", data={
        "username": "dup", "name": "x", "password": "secret1", "role": "operator",
    }, follow_redirects=False)
    assert r.status_code == 303
    assert admin_users.admin_users_collection.count_documents({"username": "dup"}) == 1


# ── 登录日志 ──

def test_login_log_records_and_flags_new_ip(client):
    _login_as(client, "admin", "admin123")
    r = client.get("/admin/login-log", follow_redirects=False)
    assert r.status_code == 200 and "admin" in r.text
    e = db["admin_login_log"].find_one({"username": "admin"})
    assert e is not None and e["is_new_ip"] is True  # 首次登录 = 陌生 IP
