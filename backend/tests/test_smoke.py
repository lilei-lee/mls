"""V2 后端 API smoke test 套件 — 每个 endpoint 至少 1 条基础 case"""
import pytest
import requests
import time
import warnings

# 屏蔽 InsecureRequestWarning(dev 环境 HTTP)
warnings.filterwarnings("ignore", message="Unverified HTTPS request")

BASE = "http://localhost:8000"
SUFFIX = str(int(time.time()))[-4:]  # 防重名后缀(4 位,字符限制 5)
DUMMY_PHOTO = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA=="


def _post(path, json=None, token=None):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.post(f"{BASE}{path}", json=json, headers=h)


def _get(path, token=None, params=None):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.get(f"{BASE}{path}", headers=h, params=params)


def _patch(path, json=None, token=None):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.patch(f"{BASE}{path}", json=json, headers=h)


def _delete(path, token=None):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.delete(f"{BASE}{path}", headers=h)


# ── fixtures ──────────────────────────────────────────────

@pytest.fixture(scope="module")
def tokens():
    """获取张三(LA)和李红(BA)的 access_token"""
    result = {}
    for name, phone in [("zhangsan", "13912345678"), ("lihong", "13200132000")]:
        # send code — 可能 429(频率限制), 重试
        for attempt in range(3):
            r = _post("/api/v1/auth/send-sms-code", {"phone": phone})
            if r.status_code == 429:
                time.sleep(20)
                continue
            break
        assert r.status_code in (200, 429), f"send code failed: {r.text}"
        time.sleep(2)
        r = _post("/api/v1/auth/login", {"phone": phone, "code": "123456"})
        assert r.status_code == 200, f"login failed ({name}): {r.text}"
        data = r.json()
        result[name] = {
            "token": data["access_token"],
            "agent_id": data["agent_id"],
            "name": data["name"],
        }
    return result


@pytest.fixture(scope="module")
def listing_id(tokens):
    """创建一个测试房源，整个 module 复用，结束后删除"""
    r = _post("/api/v1/listings", json={
        "district": "桥东区",
        "community": "smoke测试小区",
        "building": "1", "unit": "1", "room_no": f"9999{SUFFIX}",
        "layout": "2室1厅1卫", "area_sqm": 90.0, "price_wan": 80,
        "rooms": 2, "bathrooms": 1,
        "floor": 5, "total_floor": 18, "orientation": "南",
        "bonus_yuan": 3000,
    }, token=tokens["zhangsan"]["token"])
    assert r.status_code == 200, f"create listing: {r.status_code} {r.text}"
    lid = r.json()["listing_id"]
    yield lid
    _delete(f"/api/v1/listings/{lid}", token=tokens["zhangsan"]["token"])


@pytest.fixture(scope="module")
def showing_request_id(tokens, listing_id):
    """李红对测试房源发起带客申请"""
    r = _post("/api/v1/showing-requests", json={
        "listing_id": listing_id,
        "customer_surname": f"s{SUFFIX}", "customer_gender": "male",
        "requirements": "smoke test requirement",
    }, token=tokens["lihong"]["token"])
    # 400 if already has pending request
    assert r.status_code in (200, 400), f"create request: {r.text}"
    if r.status_code != 200:
        pytest.skip("cannot create showing request (may already exist)")
    return r.json()["request_id"]


@pytest.fixture(scope="module")
def showing_id(tokens, showing_request_id):
    """张三审批 + 李红提交带看 + 张三确认 → 返回 confirmed showing_id"""
    la = tokens["zhangsan"]["token"]
    ba = tokens["lihong"]["token"]

    r = _post(f"/api/v1/showing-requests/{showing_request_id}/approve",
              token=la)
    assert r.status_code == 200, f"approve: {r.text}"

    r = _post("/api/v1/showings", json={
        "showing_request_id": showing_request_id,
        "showing_time": "2026-05-06T14:00:00",
        "photo_count": 1,
        "customer_feedback": "smoke feedback",
        "photos": [DUMMY_PHOTO],
    }, token=ba)
    assert r.status_code == 200, f"submit showing: {r.text}"
    sid = r.json()["showing_id"]

    r = _post(f"/api/v1/showings/{sid}/confirm", token=la)
    assert r.status_code == 200, f"confirm showing: {r.text}"
    return sid


@pytest.fixture(scope="module")
def customer_id(tokens):
    """BA 创建测试客户"""
    r = _post("/api/v1/customers", json={
        "surname": f"smoke{SUFFIX}", "gender": "male",
    }, token=tokens["lihong"]["token"])
    assert r.status_code in (200, 409), f"create customer: {r.status_code} {r.text}"
    if r.status_code == 409:
        pytest.skip("customer already exists from prior run")
    return r.json()["data"]["customer_id"]


@pytest.fixture(scope="module")
def tx_pending_id(tokens, listing_id):
    """创建一条 pending_la_confirm 的 transaction"""
    la = tokens["zhangsan"]["token"]
    ba = tokens["lihong"]["token"]

    # ensure listing in right state
    _post(f"/api/v1/listings/{listing_id}/mark-deposit-paid",
          json={"deposit_amount_yuan": 50000}, token=la)

    # create separate request + showing for tx
    r = _post("/api/v1/showing-requests", json={
        "listing_id": listing_id,
        "customer_surname": f"t{SUFFIX}", "customer_gender": "male",
        "requirements": "tx smoke test",
    }, token=ba)
    # 可能已有 active request
    if r.status_code != 200:
        return None
    rid = r.json()["request_id"]

    _post(f"/api/v1/showing-requests/{rid}/approve", token=la)
    r = _post("/api/v1/showings", json={
        "showing_request_id": rid,
        "showing_time": "2026-05-06T10:00:00",
        "photo_count": 1, "customer_feedback": "ok",
        "photos": [DUMMY_PHOTO],
    }, token=ba)
    if r.status_code != 200:
        return None
    sid = r.json()["showing_id"]
    _post(f"/api/v1/showings/{sid}/confirm", token=la)

    r = _post("/api/v1/transactions", json={
        "showing_id": sid,
        "deal_price_yuan": 600000,
        "deal_date": "2026-05-06",
    }, token=ba)
    if r.status_code != 200:
        return None
    return r.json()["transaction_id"]


# ═══════════════════════════════════════════════════════════
# Auth (no auth required)
# ═══════════════════════════════════════════════════════════

class TestAuth:
    def test_send_sms_code(self):
        r = _post("/api/v1/auth/send-sms-code", {"phone": "13900000001"})
        assert r.status_code == 200, f"send sms: {r.text}"

    def test_register_or_exists(self):
        phone = f"139{SUFFIX}0000"  # 11 位手机号
        _post("/api/v1/auth/send-sms-code", {"phone": phone})
        time.sleep(2)
        r = _post("/api/v1/auth/register", {
            "phone": phone, "code": "123456", "name": "SmokeTester",
            "id_card": f"1307012000{SUFFIX}0000",
            "store_name": "Smoke Agency",
        })
        assert r.status_code in (200, 400, 409)

    def test_login(self, tokens):
        assert "token" in tokens["zhangsan"]
        assert "token" in tokens["lihong"]

    def test_refresh_token(self, tokens):
        r = _post("/api/v1/auth/login",
                   {"phone": "13912345678", "code": "123456"})
        if r.status_code == 200:
            refresh = r.json()["refresh_token"]
            r2 = _post("/api/v1/auth/refresh", {"refresh_token": refresh})
            assert r2.status_code == 200

    def test_logout(self, tokens):
        # 单独登录一个新 session 再登出, 避免 token rotation 干扰
        r = _post("/api/v1/auth/login",
                   {"phone": "13912345678", "code": "123456"})
        if r.status_code == 200:
            tok = r.json()["access_token"]
            r2 = _post("/api/v1/auth/logout", token=tok)
            assert r2.status_code in (200, 401), f"logout: {r2.status_code} {r2.text}"


# ═══════════════════════════════════════════════════════════
# Me
# ═══════════════════════════════════════════════════════════

class TestMe:
    def test_me(self, tokens):
        r = _get("/api/v1/me", token=tokens["zhangsan"]["token"])
        assert r.status_code == 200
        assert r.json()["name"] == "张三"


# ═══════════════════════════════════════════════════════════
# Listings
# ═══════════════════════════════════════════════════════════

class TestListings:
    def test_mine(self, tokens):
        r = _get("/api/v1/listings/mine", token=tokens["zhangsan"]["token"])
        assert r.status_code == 200
        assert "items" in r.json()

    def test_shared(self, tokens):
        r = _get("/api/v1/listings/shared", token=tokens["lihong"]["token"])
        assert r.status_code == 200
        assert "items" in r.json()

    def test_meta_districts(self, tokens):
        r = _get("/api/v1/listings/meta/districts",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_detail(self, tokens, listing_id):
        r = _get(f"/api/v1/listings/{listing_id}",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_mark_deposit_paid(self, tokens, listing_id):
        r = _post(f"/api/v1/listings/{listing_id}/mark-deposit-paid",
                   {"deposit_amount_yuan": 50000},
                   token=tokens["zhangsan"]["token"])
        assert r.status_code == 200, f"mark deposit: {r.text}"

    def test_rollback(self, tokens, listing_id):
        r = _post(f"/api/v1/listings/{listing_id}/rollback-to-on-sale",
                   {"reason": "smoke rollback"},
                   token=tokens["zhangsan"]["token"])
        assert r.status_code == 200, f"rollback: {r.text}"

    def test_reactivate(self, tokens, listing_id):
        r = _post(f"/api/v1/listings/{listing_id}/reactivate",
                   token=tokens["zhangsan"]["token"])
        # 400 if listing not offline — both fine
        assert r.status_code in (200, 400), f"reactivate: {r.text}"

    def test_update(self, tokens, listing_id):
        r = _patch(f"/api/v1/listings/{listing_id}",
                    {"price_wan": 85},
                    token=tokens["zhangsan"]["token"])
        assert r.status_code == 200, f"update: {r.text}"


# ═══════════════════════════════════════════════════════════
# Showing Requests
# ═══════════════════════════════════════════════════════════

class TestShowingRequests:
    def test_sent(self, tokens):
        r = _get("/api/v1/showing-requests/sent",
                 token=tokens["lihong"]["token"])
        assert r.status_code == 200
        assert "items" in r.json()

    def test_received(self, tokens):
        r = _get("/api/v1/showing-requests/received",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_pending_count(self, tokens):
        r = _get("/api/v1/showing-requests/pending-count",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_detail(self, tokens, showing_request_id):
        r = _get(f"/api/v1/showing-requests/{showing_request_id}",
                 token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_reject(self, tokens, listing_id):
        """新建申请后审批拒绝"""
        r = _post("/api/v1/showing-requests", {
            "listing_id": listing_id,
            "customer_surname": f"r{SUFFIX}", "customer_gender": "female",
            "requirements": "to reject smoke",
        }, token=tokens["lihong"]["token"])
        if r.status_code == 200:
            rid = r.json()["request_id"]
            r2 = _post(f"/api/v1/showing-requests/{rid}/reject",
                        {"reason": "mismatch"},
                        token=tokens["zhangsan"]["token"])
            assert r2.status_code == 200


# ═══════════════════════════════════════════════════════════
# Showings
# ═══════════════════════════════════════════════════════════

class TestShowings:
    def test_pending_confirm(self, tokens):
        r = _get("/api/v1/showings/pending-confirm",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_pending_count(self, tokens):
        r = _get("/api/v1/showings/pending-confirm-count",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_by_request(self, tokens, showing_request_id):
        r = _get(f"/api/v1/showings/by-request/{showing_request_id}",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_can_direct(self, tokens, listing_id):
        r = _get("/api/v1/showings/can-direct",
                 token=tokens["lihong"]["token"],
                 params={"listing_id": listing_id})
        assert r.status_code == 200

    def test_detail(self, tokens, showing_id):
        r = _get(f"/api/v1/showings/{showing_id}",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200


# ═══════════════════════════════════════════════════════════
# Transactions
# ═══════════════════════════════════════════════════════════

class TestTransactions:
    def test_pending_la(self, tokens):
        r = _get("/api/v1/transactions/pending",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_pending_la_count(self, tokens):
        r = _get("/api/v1/transactions/pending-count",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_detail(self, tokens, tx_pending_id):
        if tx_pending_id is None:
            pytest.skip("could not create tx")
        r = _get(f"/api/v1/transactions/{tx_pending_id}",
                 token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_la_confirm(self, tokens, tx_pending_id):
        if tx_pending_id is None:
            pytest.skip("could not create tx")
        r = _post(f"/api/v1/transactions/{tx_pending_id}/la-confirm", {
            "deal_price_yuan": 600000,
            "deal_date": "2026-05-06",
        }, token=tokens["zhangsan"]["token"])
        assert r.status_code in (200, 400, 409)

    def test_cancel(self, tokens, tx_pending_id):
        if tx_pending_id is None:
            pytest.skip("could not create tx")
        r = _post(f"/api/v1/transactions/{tx_pending_id}/cancel",
                   token=tokens["lihong"]["token"])
        assert r.status_code in (200, 400, 409)


# ═══════════════════════════════════════════════════════════
# Settlements
# ═══════════════════════════════════════════════════════════

class TestSettlements:
    def test_pending_my(self, tokens):
        r = _get("/api/v1/settlements/pending-my",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_pending_count(self, tokens):
        r = _get("/api/v1/settlements/pending-my-count",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_detail(self, tokens):
        r = _get("/api/v1/settlements/pending-my",
                 token=tokens["zhangsan"]["token"])
        items = r.json().get("items", [])
        if items:
            sid = items[0]["settlement_id"]
            r2 = _get(f"/api/v1/settlements/{sid}",
                      token=tokens["zhangsan"]["token"])
            assert r2.status_code == 200


# ═══════════════════════════════════════════════════════════
# Customers
# ═══════════════════════════════════════════════════════════

class TestCustomers:
    def test_mine(self, tokens):
        r = _get("/api/v1/customers/mine",
                 token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_detail(self, tokens, customer_id):
        r = _get(f"/api/v1/customers/{customer_id}",
                 token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_update(self, tokens, customer_id):
        r = _patch(f"/api/v1/customers/{customer_id}",
                    {"surname": "smoke2"},
                    token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_memo(self, tokens, customer_id):
        r = _post(f"/api/v1/customers/{customer_id}/memo",
                   {"text": "smoke note"},
                   token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_timeline(self, tokens, customer_id):
        r = _get(f"/api/v1/customers/{customer_id}/timeline",
                 token=tokens["lihong"]["token"])
        assert r.status_code == 200

    def test_close(self, tokens, customer_id):
        r = _patch(f"/api/v1/customers/{customer_id}/close",
                    {"reason": "smoke close"},
                    token=tokens["lihong"]["token"])
        assert r.status_code == 200


# ═══════════════════════════════════════════════════════════
# Dashboard
# ═══════════════════════════════════════════════════════════

class TestDashboard:
    def test_summary(self, tokens):
        r = _get("/api/v1/dashboard/summary",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_todos(self, tokens):
        r = _get("/api/v1/dashboard/todos",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200

    def test_recent_events(self, tokens):
        r = _get("/api/v1/dashboard/recent-events",
                 token=tokens["zhangsan"]["token"])
        assert r.status_code == 200


# ═══════════════════════════════════════════════════════════
# Communities
# ═══════════════════════════════════════════════════════════

class TestCommunities:
    def test_search(self, tokens):
        r = _get("/api/v1/communities/search",
                 token=tokens["zhangsan"]["token"],
                 params={"q": "smoke"})
        assert r.status_code == 200

    def test_detail(self, tokens):
        r = _get("/api/v1/communities/search",
                 token=tokens["zhangsan"]["token"],
                 params={"q": "保利"})
        items = r.json().get("items", [])
        if items:
            cid = items[0]["community_id"]
            r2 = _get(f"/api/v1/communities/{cid}",
                      token=tokens["zhangsan"]["token"])
            assert r2.status_code == 200


# ═══════════════════════════════════════════════════════════
# Collaborations
# ═══════════════════════════════════════════════════════════

class TestCollaborations:
    def test_mine_buyer(self, tokens):
        r = _get("/api/v1/collaborations/mine",
                 token=tokens["lihong"]["token"],
                 params={"role": "buyer"})
        assert r.status_code == 200

    def test_mine_seller(self, tokens):
        r = _get("/api/v1/collaborations/mine",
                 token=tokens["zhangsan"]["token"],
                 params={"role": "seller"})
        assert r.status_code == 200


# ═══════════════════════════════════════════════════════════
# Root
# ═══════════════════════════════════════════════════════════

class TestRoot:
    def test_root(self):
        r = requests.get(BASE)
        assert r.status_code == 200
