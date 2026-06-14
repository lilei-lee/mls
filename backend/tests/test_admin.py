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


def test_members_requires_auth(client):
    r = client.get("/admin/members", follow_redirects=False)
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/login"


# ── 看板 ──

def test_dashboard_authed(client):
    _login(client)
    r = client.get("/admin/", follow_redirects=False)
    assert r.status_code == 200
    assert "数据看板" in r.text


# ── 会员管理 ──

def test_members_grant_flow(client):
    db["agents"].insert_one({
        "name": "张三", "phone": "13912345678", "store_name": "测试门店",
        "status": "active", "created_at": datetime.now(),
    })
    _login(client)

    r = client.post("/admin/members/grant",
                    data={"phone": "13912345678", "days": "365"},
                    follow_redirects=False)
    assert r.status_code == 303

    a = db["agents"].find_one({"phone": "13912345678"})
    assert isinstance(a.get("membership_expires_at"), datetime)
    assert a["membership_expires_at"] > datetime.now()

    r2 = client.get("/admin/members", follow_redirects=False)
    assert r2.status_code == 200
    assert "张三" in r2.text
    assert "有效" in r2.text


def test_grant_unknown_phone(client):
    _login(client)
    r = client.post("/admin/members/grant",
                    data={"phone": "10000000000", "days": "30"},
                    follow_redirects=False)
    assert r.status_code == 303  # 优雅重定向回列表(带未找到提示)
