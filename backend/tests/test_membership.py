"""会员费机制纯单测 — 不依赖 MongoDB(monkeypatch 全局开关)。"""
from datetime import datetime, timedelta

import config
from membership import is_member_active, membership_info, initial_membership_expiry


# ── 免费期(开关关闭):人人完整可用 ──────────────────────────

def test_free_period_always_active(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", False)
    assert is_member_active({}) is True
    # 即便到期日是过去,免费期也照样可用
    assert is_member_active({"membership_expires_at": datetime(2000, 1, 1)}) is True


def test_free_period_info_not_readonly(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", False)
    info = membership_info({})
    assert info["enforced"] is False
    assert info["active"] is True
    assert info["read_only"] is False


# ── 收费期(开关开启):按到期日判定 ──────────────────────────

def test_enforced_no_expiry_inactive(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", True)
    assert is_member_active({}) is False


def test_enforced_past_expiry_inactive(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", True)
    assert is_member_active({"membership_expires_at": datetime.now() - timedelta(days=1)}) is False


def test_enforced_future_expiry_active(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", True)
    assert is_member_active({"membership_expires_at": datetime.now() + timedelta(days=10)}) is True


def test_info_active_member(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", True)
    exp = datetime.now() + timedelta(days=30)
    info = membership_info({"membership_expires_at": exp})
    assert info["enforced"] is True
    assert info["active"] is True
    assert info["read_only"] is False
    assert info["expires_at"] == exp.strftime("%Y-%m-%d")
    assert info["days_left"] in (29, 30)


def test_info_expired_member_read_only(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_ENFORCED", True)
    info = membership_info({})
    assert info["active"] is False
    assert info["read_only"] is True
    assert info["expires_at"] is None
    assert info["days_left"] is None


# ── 注册初始到期日 ──────────────────────────────────────────

def test_initial_expiry_none_when_zero(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_TRIAL_DAYS", 0)
    assert initial_membership_expiry() is None


def test_initial_expiry_set_when_trial(monkeypatch):
    monkeypatch.setattr(config, "MEMBERSHIP_TRIAL_DAYS", 30)
    exp = initial_membership_expiry()
    assert exp is not None and exp > datetime.now()
