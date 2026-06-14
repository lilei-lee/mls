"""Web 管理后台第一片单测:管理员登录鉴权 + 看板 + 会员授予。

走 TestClient(in-process)+ mongomock,不需起真服务。管理员默认凭据
admin/admin123(config 默认,生产用 env 覆盖)。
"""
from datetime import datetime, timedelta

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


# ── 小区库管理 ──

def _seed_community(name="阳光花园", district="桥东区"):
    from bson import ObjectId
    return db["communities"].insert_one({
        "_id": ObjectId(), "name": name, "district": district,
        "built_year": 2010, "building_count": 8, "created_at": datetime.now(),
    }).inserted_id


def test_communities_requires_auth(client):
    r = client.get("/admin/communities", follow_redirects=False)
    assert r.status_code == 303


def test_communities_list(client):
    _seed_community("阳光花园", "桥东区")
    _login(client)
    r = client.get("/admin/communities", follow_redirects=False)
    assert r.status_code == 200 and "阳光花园" in r.text


def test_community_edit_save(client):
    cid = _seed_community("阳光花园", "桥东区")
    _login(client)
    r = client.post(f"/admin/communities/{cid}",
                    data={"name": "阳光花园", "district": "桥东区", "built_year": "2008", "building_count": "12"},
                    follow_redirects=False)
    assert r.status_code == 303
    c = db["communities"].find_one({"_id": cid})
    assert c["built_year"] == 2008 and c["building_count"] == 12
    assert db["audit_log"].find_one({"action": "community_edit", "target_id": str(cid)}) is not None


def test_community_rename_duplicate_rejected(client):
    _seed_community("阳光花园", "桥东区")
    cid2 = _seed_community("月亮湾", "桥东区")
    _login(client)
    # 把 月亮湾 改名成 阳光花园(同区)→ 撞唯一,应拒绝
    client.post(f"/admin/communities/{cid2}",
                data={"name": "阳光花园", "district": "桥东区"}, follow_redirects=False)
    assert db["communities"].find_one({"_id": cid2})["name"] == "月亮湾"  # 未变


# ── 数据导出 ──

def test_export_requires_auth(client):
    r = client.get("/admin/export/agents.csv", follow_redirects=False)
    assert r.status_code == 303


def test_export_agents_csv(client):
    _seed_agent(name="张三", phone="13912345678")
    _login(client)
    r = client.get("/admin/export/agents.csv", follow_redirects=False)
    assert r.status_code == 200
    assert "text/csv" in r.headers["content-type"]
    assert "attachment" in r.headers["content-disposition"]
    assert "张三" in r.text and "姓名" in r.text
    assert db["audit_log"].find_one({"action": "export", "target_type": "agents"}) is not None


def test_export_listings_csv(client):
    _seed_listing(community="阳光小区")
    _login(client)
    r = client.get("/admin/export/listings.csv", follow_redirects=False)
    assert r.status_code == 200 and "阳光小区" in r.text and "MLS编号" in r.text


# ── 系统配置 ──

def test_config_requires_auth(client):
    r = client.get("/admin/config", follow_redirects=False)
    assert r.status_code == 303


def test_config_page_shows_params(client):
    _login(client)
    r = client.get("/admin/config", follow_redirects=False)
    assert r.status_code == 200 and "带客申请有效期(天)" in r.text


def test_config_save_and_audit(client):
    from system_config import get_config
    _login(client)
    r = client.post("/admin/config", data={
        "showing_request_expire_days": "3", "listing_max_photos": "6",
        "password_max_fails": "5", "password_lock_minutes": "15",
    }, follow_redirects=False)
    assert r.status_code == 303
    assert get_config("showing_request_expire_days") == 3
    assert db["audit_log"].find_one({"action": "config_update"}) is not None


def test_config_drives_scheduler_expiry(client):
    """过期天数设为 3,4 天前的 pending 应被过期(默认 7 不会)"""
    from system_config import set_config
    from scheduler import expire_stale_showing_requests
    from bson import ObjectId
    set_config("showing_request_expire_days", 3)
    rid = db["showing_requests"].insert_one({
        "status": "pending", "created_at": datetime.now() - timedelta(days=4),
        "listing_agent_id": ObjectId(), "buyer_agent_id": ObjectId(),
    }).inserted_id
    expire_stale_showing_requests()
    assert db["showing_requests"].find_one({"_id": rid})["status"] == "expired"


# ── 小区合并 ──

def test_community_merge_requires_auth(client):
    cid = _seed_community("甲小区", "桥东区")
    r = client.get(f"/admin/communities/{cid}/merge", follow_redirects=False)
    assert r.status_code == 303


def test_community_merge_preview(client):
    from bson import ObjectId
    A = _seed_community("旧名小区", "桥东区")
    B = _seed_community("新名小区", "桥东区")
    db["listings"].insert_one({"community": "旧名小区", "community_id": A,
                               "district": "桥东区", "status": "on_sale", "created_at": datetime.now()})
    _login(client)
    r = client.get(f"/admin/communities/{A}/merge", params={"target": str(B)}, follow_redirects=False)
    assert r.status_code == 200
    assert "1" in r.text and "新名小区" in r.text  # 影响 1 套


def test_community_merge_execute(client):
    A = _seed_community("旧名小区", "桥东区")
    B = _seed_community("新名小区", "桥东区")
    lid = db["listings"].insert_one({
        "community": "旧名小区", "community_id": A, "district": "桥东区",
        "status": "on_sale", "created_at": datetime.now(),
    }).inserted_id
    _login(client)
    r = client.post(f"/admin/communities/{A}/merge", data={"target": str(B)}, follow_redirects=False)
    assert r.status_code == 303
    l = db["listings"].find_one({"_id": lid})
    assert l["community"] == "新名小区" and l["community_id"] == B
    assert db["communities"].find_one({"_id": A}) is None
    b = db["communities"].find_one({"_id": B})
    assert "旧名小区" in (b.get("aliases") or [])
    assert db["audit_log"].find_one({"action": "community_merge"}) is not None


def test_community_merge_by_name_match(client):
    """房源用 community 名(无 community_id)也能被迁移"""
    A = _seed_community("名匹配小区", "桥西区")
    B = _seed_community("目标小区", "桥西区")
    lid = db["listings"].insert_one({
        "community": "名匹配小区", "district": "桥西区",  # 无 community_id
        "status": "on_sale", "created_at": datetime.now(),
    }).inserted_id
    _login(client)
    client.post(f"/admin/communities/{A}/merge", data={"target": str(B)}, follow_redirects=False)
    assert db["listings"].find_one({"_id": lid})["community"] == "目标小区"


# ── 争议仲裁 ──

def _seed_dispute(target_type="agent", target_id=None, status="pending"):
    from bson import ObjectId
    return db["disputes"].insert_one({
        "_id": ObjectId(), "reporter_agent_id": ObjectId(), "reporter_name": "李红",
        "target_type": target_type, "target_id": target_id or str(ObjectId()),
        "reason": "截客", "description": "私下成交", "status": status,
        "ruling": None, "penalty": None, "created_at": datetime.now(),
    }).inserted_id


def test_disputes_requires_auth(client):
    r = client.get("/admin/disputes", follow_redirects=False)
    assert r.status_code == 303


def test_disputes_list_and_detail(client):
    did = _seed_dispute()
    _login(client)
    r = client.get("/admin/disputes", follow_redirects=False)
    assert r.status_code == 200 and "截客" in r.text
    r2 = client.get(f"/admin/disputes/{did}", follow_redirects=False)
    assert r2.status_code == 200 and "私下成交" in r2.text


def test_dispute_accept(client):
    did = _seed_dispute()
    _login(client)
    r = client.post(f"/admin/disputes/{did}/accept", follow_redirects=False)
    assert r.status_code == 303
    assert db["disputes"].find_one({"_id": did})["status"] == "accepted"
    assert db["audit_log"].find_one({"action": "dispute_accept"}) is not None


def test_dispute_rule_with_ban(client):
    aid = _seed_agent()  # 被举报的经纪人
    did = _seed_dispute(target_type="agent", target_id=str(aid), status="accepted")
    _login(client)
    r = client.post(f"/admin/disputes/{did}/rule",
                    data={"ruling": "查实截客,予以踢出", "penalty": "ban"}, follow_redirects=False)
    assert r.status_code == 303
    d = db["disputes"].find_one({"_id": did})
    assert d["status"] == "resolved" and d["penalty"] == "ban"
    # 联动踢出目标经纪人
    assert db["agents"].find_one({"_id": aid})["status"] == "banned"
    assert db["audit_log"].find_one({"action": "dispute_resolve"}) is not None


def test_dispute_reject(client):
    did = _seed_dispute()
    _login(client)
    r = client.post(f"/admin/disputes/{did}/reject", data={"ruling": "证据不足"}, follow_redirects=False)
    assert r.status_code == 303
    d = db["disputes"].find_one({"_id": did})
    assert d["status"] == "rejected" and d["ruling"] == "证据不足"


# ── 定金异常审查 ──

def test_deposit_watch_requires_auth(client):
    r = client.get("/admin/deposit-watch", follow_redirects=False)
    assert r.status_code == 303


def test_deposit_watch_flags_repeated(client):
    from bson import ObjectId
    now = datetime.now()
    db["listings"].insert_one({"_id": ObjectId(), "community": "频繁小区", "building": "1", "room_no": "1",
                               "owner_agent_name": "张三", "created_at": now,
                               "deposit_events": [{"type": "deposit", "at": now} for _ in range(3)]})
    db["listings"].insert_one({"_id": ObjectId(), "community": "正常小区", "building": "2", "room_no": "2",
                               "owner_agent_name": "李红", "created_at": now,
                               "deposit_events": [{"type": "deposit", "at": now}]})
    _login(client)
    r = client.get("/admin/deposit-watch", follow_redirects=False)
    assert r.status_code == 200 and "频繁小区" in r.text and "正常小区" in r.text


def test_mark_deposit_pushes_event(client):
    """mark_listing_deposit_paid 写入 deposit_events(供定金监控统计)"""
    from bson import ObjectId
    from services.listings import mark_listing_deposit_paid, MarkDepositPaidBody
    aid = ObjectId()
    lid = db["listings"].insert_one({
        "owner_agent_id": aid, "owner_agent_name": "张三", "owner_agent_phone": "139",
        "status": "on_sale", "house_code": "HC-DEP-1",
        "community": "测", "building": "1", "unit": "1", "room_no": "1", "district": "桥东区",
        "orientation": "南", "price_wan": 80.0, "bonus_yuan": 0,
        "photos": [], "photo_count": 0, "sale_points": [],
        "public_remarks": "", "agent_remarks": "", "showing_instructions": "",
        "price_history": [], "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id
    mark_listing_deposit_paid(str(lid), MarkDepositPaidBody(), aid)
    l = db["listings"].find_one({"_id": lid})
    assert l["status"] == "deposit_paid"
    assert any(e.get("type") == "deposit" for e in l.get("deposit_events", []))


# ── 经纪人暂停/解除 ──

def test_agent_suspend_and_unsuspend(client):
    aid = _seed_agent()
    _login(client)
    r = client.post(f"/admin/agents/{aid}/suspend", data={"reason": "核实中"}, follow_redirects=False)
    assert r.status_code == 303
    a = db["agents"].find_one({"_id": aid})
    assert a["status"] == "suspended" and a["status_reason"] == "核实中"
    assert db["audit_log"].find_one({"action": "agent_suspend", "target_id": str(aid)}) is not None
    # 解除
    client.post(f"/admin/agents/{aid}/unsuspend", follow_redirects=False)
    assert db["agents"].find_one({"_id": aid})["status"] == "active"
    assert db["audit_log"].find_one({"action": "agent_unsuspend", "target_id": str(aid)}) is not None


def test_suspend_only_active(client):
    """已踢出的经纪人不能被'暂停'(状态守卫)"""
    aid = _seed_agent()
    db["agents"].update_one({"_id": aid}, {"$set": {"status": "banned"}})
    _login(client)
    client.post(f"/admin/agents/{aid}/suspend", data={"reason": "x"}, follow_redirects=False)
    assert db["agents"].find_one({"_id": aid})["status"] == "banned"  # 未变


# ── 定金凭证审核 ──

def test_proof_src_helper():
    from routers.admin import _proof_src
    assert _proof_src("data:image/png;base64,xxx").startswith("data:")
    assert _proof_src("abc123key") == "/admin/photo/abc123key"
    assert _proof_src("/api/v1/photos/k/e/y") == "/admin/photo/k/e/y"
    assert _proof_src("") == ""


def test_deposit_proofs_requires_auth(client):
    r = client.get("/admin/deposit-proofs", follow_redirects=False)
    assert r.status_code == 303


def test_deposit_proofs_list(client):
    from bson import ObjectId
    db["listings"].insert_one({
        "_id": ObjectId(), "status": "deposit_paid", "community": "押小区",
        "building": "1", "room_no": "1", "owner_agent_name": "张三",
        "deposit_amount_yuan": 50000, "deposit_proof_url": "proofkey123",
        "deposit_paid_at": datetime.now(),
    })
    _login(client)
    r = client.get("/admin/deposit-proofs", follow_redirects=False)
    assert r.status_code == 200 and "押小区" in r.text and "查看凭证" in r.text


def test_review_proof_records_and_audits(client):
    from bson import ObjectId
    lid = db["listings"].insert_one({
        "_id": ObjectId(), "status": "deposit_paid", "community": "押",
        "deposit_proof_url": "k", "deposit_paid_at": datetime.now(),
    }).inserted_id
    _login(client)
    r = client.post(f"/admin/listings/{lid}/review-proof",
                    data={"result": "reject", "reason": "凭证模糊"}, follow_redirects=False)
    assert r.status_code == 303
    l = db["listings"].find_one({"_id": lid})
    assert l["deposit_proof_review"]["result"] == "reject"
    assert l["deposit_proof_review"]["reason"] == "凭证模糊"
    assert db["audit_log"].find_one({"action": "deposit_proof_review"}) is not None
