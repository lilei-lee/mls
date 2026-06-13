"""UpdateListingRequest 校验单测 — 纯 Pydantic,不依赖 MongoDB。

回归保护:PATCH /listings/{id} 的请求体校验约束必须与创建路径
(CreateListingRequest) 对齐,防止 price_wan 负数 / bonus_yuan 超界 /
备注超长绕过创建时的闸门。
"""
import pytest
from pydantic import ValidationError

from routers.listings import UpdateListingRequest


# ── 合法值放行 ───────────────────────────────────────────────

def test_partial_update_ok():
    """部分更新合法值 — 全部放行"""
    m = UpdateListingRequest(price_wan=120, bonus_yuan=3000)
    assert m.price_wan == 120
    assert m.bonus_yuan == 3000


def test_empty_update_ok():
    """空 PATCH 合法(业务层再判没有有效字段)"""
    m = UpdateListingRequest()
    assert m.price_wan is None


def test_bonus_boundaries_ok():
    """bonus_yuan 边界值 0 / 500000 放行"""
    assert UpdateListingRequest(bonus_yuan=0).bonus_yuan == 0
    assert UpdateListingRequest(bonus_yuan=500_000).bonus_yuan == 500_000


# ── 非法值拦截 ───────────────────────────────────────────────

def test_negative_price_rejected():
    """price_wan 负数 → 拦截(债:旧版允许负数)"""
    with pytest.raises(ValidationError):
        UpdateListingRequest(price_wan=-1)


def test_zero_price_rejected():
    """price_wan 0 → 拦截(gt=0)"""
    with pytest.raises(ValidationError):
        UpdateListingRequest(price_wan=0)


def test_negative_bonus_rejected():
    with pytest.raises(ValidationError):
        UpdateListingRequest(bonus_yuan=-100)


def test_bonus_over_cap_rejected():
    """bonus_yuan 超 500000 上限 → 拦截"""
    with pytest.raises(ValidationError):
        UpdateListingRequest(bonus_yuan=500_001)


def test_public_remarks_too_long_rejected():
    with pytest.raises(ValidationError):
        UpdateListingRequest(public_remarks="x" * 2001)


def test_agent_remarks_too_long_rejected():
    with pytest.raises(ValidationError):
        UpdateListingRequest(agent_remarks="x" * 1001)


def test_showing_instructions_too_long_rejected():
    with pytest.raises(ValidationError):
        UpdateListingRequest(showing_instructions="x" * 501)


def test_orientation_too_long_rejected():
    with pytest.raises(ValidationError):
        UpdateListingRequest(orientation="x" * 21)
