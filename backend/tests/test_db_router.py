"""V3 db_router 单测 — 4 条,不依赖真实 MongoDB

⚠️ 历史坑:本文件曾在模块顶层 `sys.modules["database"] = mock_db` 且永不还原,
导致其后所有测试 `from database import db` 拿到 MagicMock(insert_one().inserted_id
/ count_documents() 全是 Mock)→ 全量跑时污染 ~60 个 DB 测试。
现改为 autouse fixture:每个测试 patch database 为 mock,结束即还原,不外溢。
"""
import sys
from unittest.mock import MagicMock

import pytest

# db_router.get_db() 内部 `from database import client` 是惰性的,
# 因此本行模块级 import 无需 database 被 mock(真假皆可)。
from db_router import get_db, get_current_city, DEFAULT_MLS_CITY  # noqa: E402


def _make_mock_db(key):
    m = MagicMock()
    m.name = key
    return m


@pytest.fixture(autouse=True)
def _mock_database():
    """临时把 database 模块换成 mock(供 get_db 的惰性 import 用),测试后还原。"""
    orig = sys.modules.get("database")
    mock_db = MagicMock()
    mock_db.client = MagicMock()
    mock_db.client.__getitem__.side_effect = _make_mock_db
    sys.modules["database"] = mock_db
    try:
        yield
    finally:
        if orig is not None:
            sys.modules["database"] = orig
        else:
            sys.modules.pop("database", None)


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
