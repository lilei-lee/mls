"""密码登录相关纯单测 — 不依赖 MongoDB(fakeredis 在进程内)。

覆盖:bcrypt 哈希/校验、密码强度规则、Set/Reset 请求体校验、防爆破锁定计数。
"""
import pytest
from pydantic import ValidationError

from auth import (
    hash_password, verify_password, validate_password_strength,
    is_password_locked, register_password_fail, clear_password_fails,
    PWD_MAX_FAILS, SetPasswordRequest, ResetPasswordRequest,
)


# ── bcrypt 哈希 / 校验 ───────────────────────────────────────

def test_hash_verify_roundtrip():
    h = hash_password("abc123")
    assert h != "abc123"          # 绝不存明文
    assert verify_password("abc123", h) is True
    assert verify_password("abc124", h) is False


def test_hash_is_salted_unique():
    """同一密码两次哈希结果不同(加盐),但都能校验通过"""
    h1, h2 = hash_password("abc123"), hash_password("abc123")
    assert h1 != h2
    assert verify_password("abc123", h1)
    assert verify_password("abc123", h2)


def test_verify_handles_empty_or_bad_hash():
    assert verify_password("abc123", None) is False
    assert verify_password("abc123", "") is False
    assert verify_password("abc123", "not-a-bcrypt-hash") is False


# ── 密码强度规则 ─────────────────────────────────────────────

def test_strength_accepts_valid():
    assert validate_password_strength("abc123") == "abc123"
    assert validate_password_strength("Pass1234") == "Pass1234"


@pytest.mark.parametrize("bad,reason", [
    ("ab1", "太短"),
    ("a" * 33 + "1", "太长"),
    ("123456", "纯数字无字母"),
    ("abcdef", "纯字母无数字"),
    ("abc 123", "含空格"),
])
def test_strength_rejects_invalid(bad, reason):
    with pytest.raises(ValueError):
        validate_password_strength(bad)


# ── Pydantic 请求体把强度校验挡在入口 ────────────────────────

def test_set_password_request_rejects_weak():
    with pytest.raises(ValidationError):
        SetPasswordRequest(new_password="123456")  # 无字母


def test_set_password_request_accepts_strong():
    m = SetPasswordRequest(old_password="old123", new_password="new123")
    assert m.new_password == "new123"


def test_reset_password_request_rejects_weak():
    with pytest.raises(ValidationError):
        ResetPasswordRequest(phone="13912345678", code="123456", new_password="abcdef")


def test_reset_password_request_validates_phone_and_code():
    # 手机号格式错
    with pytest.raises(ValidationError):
        ResetPasswordRequest(phone="139", code="123456", new_password="new123")
    # 验证码非 6 位
    with pytest.raises(ValidationError):
        ResetPasswordRequest(phone="13912345678", code="12", new_password="new123")


# ── 防爆破锁定计数(fakeredis) ───────────────────────────────

def test_lockout_after_max_fails():
    phone = "13900000001"
    clear_password_fails(phone)
    assert is_password_locked(phone) is False
    for _ in range(PWD_MAX_FAILS - 1):
        register_password_fail(phone)
    assert is_password_locked(phone) is False   # 还差一次
    register_password_fail(phone)
    assert is_password_locked(phone) is True     # 达到阈值,锁定
    clear_password_fails(phone)
    assert is_password_locked(phone) is False     # 清除后解锁


def test_clear_resets_counter():
    phone = "13900000002"
    clear_password_fails(phone)
    for _ in range(PWD_MAX_FAILS):
        register_password_fail(phone)
    assert is_password_locked(phone) is True
    clear_password_fails(phone)
    assert is_password_locked(phone) is False
