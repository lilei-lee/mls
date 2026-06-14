"""客户管理升级 — 纯 Pydantic 模型校验单测(不依赖 MongoDB)。"""
import pytest
from datetime import datetime
from pydantic import ValidationError

from customers import (
    CreateCustomerRequest, UpdateCustomerRequest, IntentCommunity,
    _parse_ymd, STATUS_OPTIONS, ACTIVE_STATUSES,
)


def _valid(**override):
    base = dict(surname="王", gender="male")
    base.update(override)
    return base


# ── 合法 ─────────────────────────────────────────────────────

def test_create_minimal_ok():
    m = CreateCustomerRequest(**_valid())
    assert m.surname == "王"


def test_create_full_ok():
    m = CreateCustomerRequest(**_valid(
        phone="13900001111", phone_alt="13800002222", wechat="wxid_abc",
        source="转介绍", intent_grade="A",
        budget_min_wan=80, budget_max_wan=120,
        intent_districts=["桥东区", "桥西区"],
        intent_communities=[{"name": "中泰城", "district": "桥东区"}],
        rooms_need=3, halls_need=2, baths_need=2, area_need="90-110㎡",
        purpose="刚需", payment="商贷", tags=["诚意客", "急"],
        next_follow_up_at="2026-06-20",
    ))
    assert m.intent_grade == "A"
    assert m.intent_communities[0].name == "中泰城"
    assert m.purpose == "刚需"


# ── 枚举白名单 ───────────────────────────────────────────────

@pytest.mark.parametrize("field,bad", [
    ("purpose", "自住"),        # 已改名为"刚需"
    ("payment", "分期"),
    ("source", "天上掉的"),
    ("intent_grade", "D"),
])
def test_enum_rejects_invalid(field, bad):
    with pytest.raises(ValidationError):
        CreateCustomerRequest(**_valid(**{field: bad}))


def test_purpose_accepts_new_options():
    for p in ("刚需", "改善", "投资", "婚房", "学区", "养老"):
        assert CreateCustomerRequest(**_valid(purpose=p)).purpose == p


# ── 业务规则校验 ─────────────────────────────────────────────

def test_budget_min_gt_max_rejected():
    with pytest.raises(ValidationError):
        CreateCustomerRequest(**_valid(budget_min_wan=200, budget_max_wan=100))


def test_budget_equal_ok():
    assert CreateCustomerRequest(**_valid(budget_min_wan=100, budget_max_wan=100))


def test_tag_too_long_rejected():
    with pytest.raises(ValidationError):
        CreateCustomerRequest(**_valid(tags=["这个标签实在是太长了超过十二字了啊"]))


def test_intent_community_requires_name():
    with pytest.raises(ValidationError):
        IntentCommunity(district="桥东区")


def test_next_follow_up_bad_format_rejected():
    with pytest.raises(ValidationError):
        CreateCustomerRequest(**_valid(next_follow_up_at="2026/06/20"))


def test_phone_alt_pattern():
    with pytest.raises(ValidationError):
        CreateCustomerRequest(**_valid(phone_alt="12345"))


# ── Update 模型 ──────────────────────────────────────────────

def test_update_status_valid():
    for s in STATUS_OPTIONS:
        assert UpdateCustomerRequest(status=s).status == s


def test_update_status_invalid_rejected():
    with pytest.raises(ValidationError):
        UpdateCustomerRequest(status="closed")  # 旧值已废弃


def test_update_all_optional():
    m = UpdateCustomerRequest()  # 空 PATCH 合法
    assert m.surname is None and m.status is None


# ── 常量 / 辅助 ──────────────────────────────────────────────

def test_active_statuses_subset():
    assert set(ACTIVE_STATUSES) <= set(STATUS_OPTIONS)
    assert "deal" not in ACTIVE_STATUSES and "lost" not in ACTIVE_STATUSES


def test_parse_ymd():
    assert _parse_ymd(None) is None
    assert _parse_ymd("") is None
    assert _parse_ymd("2026-06-20") == datetime(2026, 6, 20)
