"""Web 管理后台 — 管理员会话(自签名 cookie,零新增依赖)+ 功能区级权限。

登录成功后下发 HMAC-SHA256 签名 cookie(用 SECRET_KEY 签),cookie 内含
**用户名**,每次请求验签 + 验过期 + 回库取角色/权限。

鉴权与权限在同一个 require_admin 依赖里完成(所有 admin 路由都已挂它):
1. 验 cookie → 取 username → 回 admin_users 查在用账号
2. 把 admin 挂到 request.state.admin(模板/审计用)
3. 按 request 路径推出所需功能区权限,无权 → 跳 /admin/denied

另有一个轻量纯 ASGI 中间件,把当前管理员用户名写进 ContextVar,
让 audit.write_audit 默认把操作归到"具体的人"(商用后台必须可追溯到人)。
"""
import contextvars
import hmac
import hashlib
import time

from fastapi import HTTPException, Request, status

from config import SECRET_KEY

COOKIE_NAME = "mls_admin"
MAX_AGE = 8 * 3600  # 8 小时

# 当前操作管理员(由中间件按 cookie 设置;审计日志默认归属到这个人)
current_actor: contextvars.ContextVar = contextvars.ContextVar("current_actor", default=None)


def _sign(payload: str) -> str:
    return hmac.new(SECRET_KEY.encode(), payload.encode(), hashlib.sha256).hexdigest()


def make_admin_cookie(username: str) -> str:
    """登录成功后下发的签名 cookie:<username>:<expire_ts>:<sig>。"""
    exp = str(int(time.time()) + MAX_AGE)
    payload = f"{username}:{exp}"
    return f"{payload}:{_sign(payload)}"


def username_from_cookie(value: str | None) -> str | None:
    """验签 + 验过期,返回 cookie 里的用户名;非法/过期 → None。"""
    if not value:
        return None
    try:
        username, exp, sig = value.rsplit(":", 2)
        payload = f"{username}:{exp}"
        if not hmac.compare_digest(sig, _sign(payload)):
            return None
        if int(exp) < int(time.time()):
            return None
        return username or None
    except Exception:
        return None


def require_admin(request: Request):
    """所有 admin 路由的依赖:登录校验 + 功能区权限校验。

    - 未登录 → 303 跳登录页
    - 已登录但无该功能区权限 → 303 跳 /admin/denied
    - 通过 → 返回带 perms 的 admin doc,并挂到 request.state.admin
    """
    from admin_users import get_admin, required_perm, has_perm

    username = username_from_cookie(request.cookies.get(COOKIE_NAME))
    admin = get_admin(username) if username else None
    if not admin or admin.get("status") != "active":
        raise HTTPException(status_code=status.HTTP_303_SEE_OTHER,
                            headers={"Location": "/admin/login"})
    request.state.admin = admin

    perm = required_perm(request.url.path)
    if not has_perm(admin, perm):
        raise HTTPException(status_code=status.HTTP_303_SEE_OTHER,
                            headers={"Location": f"/admin/denied?p={perm or ''}"})
    return admin


class ActorContextMiddleware:
    """纯 ASGI 中间件:按 cookie 解出管理员用户名写入 ContextVar。

    放在 BaseHTTPMiddleware 之外用纯 ASGI,确保 ContextVar 能被 copy 进
    线程池里跑的同步视图(审计日志在视图里调用,需读到这个值)。
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope.get("type") != "http":
            await self.app(scope, receive, send)
            return
        token = None
        try:
            req = Request(scope)
            username = username_from_cookie(req.cookies.get(COOKIE_NAME))
            if username:
                token = current_actor.set(username)
        except Exception:
            token = None
        try:
            await self.app(scope, receive, send)
        finally:
            if token is not None:
                current_actor.reset(token)
