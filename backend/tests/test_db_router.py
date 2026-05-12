"""V3 db_router 单测 — 4 条,不依赖真实 MongoDB"""

import sys
from unittest.mock import MagicMock

# 必须在导入 db_router 前 mock database 模块,
# 因为 get_db() 内部会 from database import client
mock_db = MagicMock()


def _make_mock_db(key):
    m = MagicMock()
    m.name = key
    return m


mock_db.client = MagicMock()
mock_db.client.__getitem__.side_effect = _make_mock_db
sys.modules["database"] = mock_db

from db_router import get_db, get_current_city, DEFAULT_MLS_CITY  # noqa: E402


# ── 1 ────────────────────────────────────────────────────────

def test_get_db_default():
    db = get_db()
    assert db.name == "mls_zhangjiakou"


# ── 2 ────────────────────────────────────────────────────────

def test_get_db_with_city():
    db1 = get_db("shijiazhuang")
    assert db1.name == "mls_shijiazhuang"

    db2 = get_db("baoding")
    assert db2.name == "mls_baoding"


# ── 3 ────────────────────────────────────────────────────────

class MockRequest:
    def __init__(self, headers=None):
        self.headers = headers or {}


def test_get_current_city_from_header():
    req = MockRequest(headers={"X-MLS-City": "shijiazhuang"})
    assert get_current_city(req) == "shijiazhuang"


# ── 4 ────────────────────────────────────────────────────────

def test_get_current_city_fallback():
    req = MockRequest()
    assert get_current_city(req) == "zhangjiakou"
