"""Web 管理后台 — 管理员会话(自签名 cookie,零新增依赖)。

种子期单管理员账号(config.ADMIN_USERNAME/ADMIN_PASSWORD)。登录成功后下发
HMAC-SHA256 签名 cookie(用 SECRET_KEY 签),每次请求验签 + 验过期。

不引入 itsdangerous / SessionMiddleware,用 stdlib hmac 即可。
"""
import hmac
import hashlib
import time

from fastapi import HTTPException, Request, status

from config import SECRET_KEY, ADMIN_USERNAME, ADMIN_PASSWORD

COOKIE_NAME = "mls_admin"
MAX_AGE = 8 * 3600  # 8 小时


def _sign(payload: str) -> str:
    return hmac.new(SECRET_KEY.encode(), payload.encode(), hashlib.sha256).hexdigest()


def make_admin_cookie() -> str:
    """登录成功后下发的签名 cookie 值:admin:<expire_ts>:<sig>"""
    exp = str(int(time.time()) + MAX_AGE)
    payload = f"admin:{exp}"
    return f"{payload}:{_sign(payload)}"


def verify_admin_cookie(value: str | None) -> bool:
    if not value:
        return False
    try:
        role, exp, sig = value.rsplit(":", 2)
        payload = f"{role}:{exp}"
        if not hmac.compare_digest(sig, _sign(payload)):
            return False
        if int(exp) < int(time.time()):
            return False
        return role == "admin"
    except Exception:
        return False


def check_credentials(username: str, password: str) -> bool:
    """常量时间比对账号密码。"""
    u_ok = hmac.compare_digest(username or "", ADMIN_USERNAME)
    p_ok = hmac.compare_digest(password or "", ADMIN_PASSWORD)
    return u_ok and p_ok


def require_admin(request: Request):
    """页面路由依赖:未登录 → 303 重定向到登录页。"""
    if not verify_admin_cookie(request.cookies.get(COOKIE_NAME)):
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/admin/login"},
        )
    return True
