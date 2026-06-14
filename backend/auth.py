"""JWT 工具层 + 认证路由

拆自 main.py L182-512。
"""
import hashlib
import random
import re
from datetime import datetime, timedelta
from typing import Optional
import bcrypt
from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field, field_validator
import fakeredis
from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_HOURS, REFRESH_TOKEN_EXPIRE_DAYS, DEV_SMS_CODE
from database import agents_collection
from membership import initial_membership_expiry, membership_info
from bson import ObjectId
from jose import jwt, JWTError

# 密钥/token 签发/refresh 黑名单/get_current_agent

redis_client = fakeredis.FakeStrictRedis(decode_responses=True)

# ==================== JWT 配置 ====================
# SECRET_KEY / ALGORITHM / token 过期时间 从 config 统一读取
# 生产环境必须通过环境变量 SECRET_KEY 覆盖默认值


def create_access_token(agent_id: str) -> str:
    """签发 access token（2h 过期）。payload: {sub, exp, type:'access'}"""
    expire = datetime.utcnow() + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    payload = {"sub": agent_id, "exp": expire, "type": "access"}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(agent_id: str) -> str:
    """签发 refresh token（30d 过期）。payload: {sub, exp, type:'refresh'}"""
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": agent_id, "exp": expire, "type": "refresh"}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def blacklist_refresh_token(token: str, payload: dict) -> None:
    now_ts = int(datetime.utcnow().timestamp())
    exp_ts = int(payload.get("exp", 0))
    ttl = max(exp_ts - now_ts, 1)
    key = f"rt_blacklist:{_token_hash(token)}"
    redis_client.setex(key, ttl, "1")


def is_refresh_token_blacklisted(token: str) -> bool:
    key = f"rt_blacklist:{_token_hash(token)}"
    return redis_client.exists(key) > 0


# ==================== 密码 ====================
# 日常登录走密码(省掉每次登录的短信费);注册/重置等低频动作仍用短信。
# 密码用 bcrypt 加盐哈希存储,数据库里永远没有明文。

def hash_password(plain: str) -> str:
    """bcrypt 加盐哈希。bcrypt 上限 72 字节,密码策略限 32 位,安全。"""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: Optional[str]) -> bool:
    """校验明文密码与哈希。哈希为空或损坏时安全返回 False,不抛异常。"""
    if not hashed:
        return False
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


PASSWORD_MIN = 6
PASSWORD_MAX = 32


def validate_password_strength(pw: str) -> str:
    """密码规则:6-32 位、至少含一个字母和一个数字、不含空白字符。
    校验失败抛 ValueError(Pydantic 会转成 422)。返回原值方便链式。
    """
    if not (PASSWORD_MIN <= len(pw) <= PASSWORD_MAX):
        raise ValueError(f"密码长度需 {PASSWORD_MIN}-{PASSWORD_MAX} 位")
    if re.search(r"\s", pw):
        raise ValueError("密码不能包含空格")
    if not re.search(r"[A-Za-z]", pw) or not re.search(r"\d", pw):
        raise ValueError("密码需同时包含字母和数字")
    return pw


# ── 密码登录防爆破:同手机号连续输错锁定 ──────────────────────
PWD_MAX_FAILS = 5          # 连续错 5 次
PWD_LOCK_SECONDS = 15 * 60  # 锁 15 分钟


def _pwd_fail_key(phone: str) -> str:
    return f"pwd:fail:{phone}"


def is_password_locked(phone: str) -> bool:
    v = redis_client.get(_pwd_fail_key(phone))
    return v is not None and int(v) >= PWD_MAX_FAILS


def register_password_fail(phone: str) -> int:
    """记一次失败,返回当前累计失败数。首次失败时设 TTL。"""
    key = _pwd_fail_key(phone)
    n = redis_client.incr(key)
    if n == 1:
        redis_client.expire(key, PWD_LOCK_SECONDS)
    return n


def clear_password_fails(phone: str) -> None:
    redis_client.delete(_pwd_fail_key(phone))


security = HTTPBearer()


def get_current_agent(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """核心鉴权依赖 — 解码 JWT → 查 MongoDB → 验封禁/注销。

    所有受保护路由通过 Depends(get_current_agent) 复用此函数。
    返回 agent dict（包含 _id/name/phone/role/status 等字段）。
    新路由接入：在函数参数中加 `agent: dict = Depends(get_current_agent)` 即可。
    """
    token = credentials.credentials
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="身份验证失败,请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise unauthorized
        agent_id = payload.get("sub")
        if not agent_id:
            raise unauthorized
    except JWTError:
        raise unauthorized

    agent = agents_collection.find_one({"_id": ObjectId(agent_id)})
    if not agent:
        raise unauthorized
    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")
    return agent


def get_agent_from_token(token: str):
    """从 access token 解出 agent(任何失败返 None,不抛)。供会员中间件用。"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            return None
        agent_id = payload.get("sub")
        if not agent_id:
            return None
        return agents_collection.find_one({"_id": ObjectId(agent_id)})
    except Exception:
        return None


auth_router = APIRouter(prefix="/api/v1", tags=['auth'])

# ═══════════════════ 认证 ═══════════════════
# 路由: /auth/send-sms-code, /auth/register, /auth/login, /auth/refresh, /auth/logout, /me

# ==================== 数据模型 ====================

class SendSmsRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号")


class SendSmsResponse(BaseModel):
    success: bool
    message: str


@auth_router.post("/auth/send-sms-code", response_model=SendSmsResponse)
def send_sms_code(req: SendSmsRequest):
    rate_limit_key = f"sms:ratelimit:{req.phone}"
    if redis_client.exists(rate_limit_key):
        raise HTTPException(status_code=429, detail="请求过于频繁,请60秒后再试")
    code = DEV_SMS_CODE  # 开发期固定值，方便测试。生产环境通过 DEV_SMS_CODE 环境变量覆盖
    redis_client.setex(f"sms:code:{req.phone}", 300, code)
    redis_client.setex(rate_limit_key, 60, "1")
    print(f"\n{'=' * 50}")
    print(f"[MOCK SMS] {datetime.now().strftime('%H:%M:%S')}")
    print(f"  手机号: {req.phone}")
    print(f"  验证码: {code}")
    print(f"  有效期: 5分钟")
    print(f"{'=' * 50}\n")
    return SendSmsResponse(
        success=True,
        message=f"验证码已发送至 {req.phone[:3]}****{req.phone[-4:]}"
    )


class RegisterRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    code: str = Field(..., pattern=r"^\d{6}$")
    name: str = Field(..., min_length=2, max_length=20)
    id_card: str = Field(..., pattern=r"^\d{17}[\dX]$")
    store_name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=PASSWORD_MIN, max_length=PASSWORD_MAX,
                          description="登录密码,6-32 位含字母+数字")

    @field_validator("password")
    @classmethod
    def _check_strength(cls, v):
        return validate_password_strength(v)


class RegisterResponse(BaseModel):
    success: bool
    agent_id: str
    name: str
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    message: str


@auth_router.post("/auth/register", response_model=RegisterResponse)
def register(req: RegisterRequest):
    stored_code = redis_client.get(f"sms:code:{req.phone}")
    if not stored_code:
        raise HTTPException(status_code=400, detail="验证码已过期,请重新获取")
    if stored_code != req.code:
        raise HTTPException(status_code=400, detail="验证码错误")

    if agents_collection.find_one({"phone": req.phone}):
        raise HTTPException(status_code=409, detail="该手机号已注册")
    if agents_collection.find_one({"id_card": req.id_card}):
        raise HTTPException(status_code=409, detail="该身份证号已注册")

    new_agent = {
        "phone": req.phone,
        "name": req.name,
        "id_card": req.id_card,
        "password_hash": hash_password(req.password),
        "avatar_url": "",
        "store_id": "",
        "store_name": req.store_name,
        "role": "agent",
        "status": "active",
        "coop_verified": False,
        "membership_expires_at": initial_membership_expiry(),
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
        "last_login_at": datetime.now(),
        "devices": [],
        "wechat_unionid": None,
    }
    result = agents_collection.insert_one(new_agent)
    agent_id = str(result.inserted_id)
    redis_client.delete(f"sms:code:{req.phone}")
    access_token = create_access_token(agent_id)
    refresh_token = create_refresh_token(agent_id)
    print(f"\n[OK] 新经纪人注册并自动登录: {req.name} ({req.phone})")
    return RegisterResponse(
        success=True,
        agent_id=agent_id,
        name=req.name,
        access_token=access_token,
        refresh_token=refresh_token,
        message=f"注册成功,欢迎 {req.name}!",
    )


class LoginRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    code: str = Field(..., pattern=r"^\d{6}$")


class LoginResponse(BaseModel):
    success: bool
    agent_id: str
    name: str
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    message: str


@auth_router.post("/auth/login", response_model=LoginResponse)
def login(req: LoginRequest):
    stored_code = redis_client.get(f"sms:code:{req.phone}")
    if not stored_code:
        raise HTTPException(status_code=400, detail="验证码已过期,请重新获取")
    if stored_code != req.code:
        raise HTTPException(status_code=400, detail="验证码错误")

    agent = agents_collection.find_one({"phone": req.phone})
    if not agent:
        raise HTTPException(status_code=404, detail="手机号未注册,请先注册")
    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")

    agent_id = str(agent["_id"])
    access_token = create_access_token(agent_id)
    refresh_token = create_refresh_token(agent_id)
    agents_collection.update_one(
        {"_id": agent["_id"]},
        {"$set": {"last_login_at": datetime.now()}}
    )
    redis_client.delete(f"sms:code:{req.phone}")
    print(f"\n[OK] 登录成功: {agent['name']} ({req.phone})")
    return LoginResponse(
        success=True,
        agent_id=agent_id,
        name=agent["name"],
        access_token=access_token,
        refresh_token=refresh_token,
        message=f"欢迎回来, {agent['name']}!"
    )


# ==================== 密码登录 / 设置 / 重置 ====================

class LoginPasswordRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    password: str = Field(..., min_length=1, max_length=PASSWORD_MAX)


@auth_router.post("/auth/login-password", response_model=LoginResponse)
def login_password(req: LoginPasswordRequest):
    """密码登录(日常主力,不发短信)。同手机号连错 5 次锁 15 分钟。"""
    if is_password_locked(req.phone):
        raise HTTPException(
            status_code=429,
            detail="密码错误次数过多,请15分钟后再试,或改用短信验证码登录",
        )

    agent = agents_collection.find_one({"phone": req.phone})
    # 账号存在但还没设密码 —— 明确引导,不计入失败(本就没有密码可错)
    if agent and not agent.get("password_hash"):
        raise HTTPException(
            status_code=400,
            detail="该账号未设置密码,请用短信验证码登录后,在设置里设置密码",
        )
    # 手机号不存在 / 密码错误 —— 统一文案,避免账号枚举;计一次失败
    if not agent or not verify_password(req.password, agent.get("password_hash")):
        register_password_fail(req.phone)
        raise HTTPException(status_code=401, detail="手机号或密码错误")

    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")

    clear_password_fails(req.phone)
    agent_id = str(agent["_id"])
    access_token = create_access_token(agent_id)
    refresh_token = create_refresh_token(agent_id)
    agents_collection.update_one(
        {"_id": agent["_id"]},
        {"$set": {"last_login_at": datetime.now()}}
    )
    print(f"\n[OK] 密码登录成功: {agent['name']} ({req.phone})")
    return LoginResponse(
        success=True,
        agent_id=agent_id,
        name=agent["name"],
        access_token=access_token,
        refresh_token=refresh_token,
        message=f"欢迎回来, {agent['name']}!",
    )


class SetPasswordRequest(BaseModel):
    old_password: Optional[str] = Field(None, max_length=PASSWORD_MAX,
                                        description="已设过密码时必填,用于校验本人")
    new_password: str = Field(..., min_length=PASSWORD_MIN, max_length=PASSWORD_MAX)

    @field_validator("new_password")
    @classmethod
    def _check_strength(cls, v):
        return validate_password_strength(v)


@auth_router.post("/auth/set-password")
def set_password(req: SetPasswordRequest, agent: dict = Depends(get_current_agent)):
    """已登录用户设/改自己的密码。已有密码时需校验旧密码;首次设置免旧密码。"""
    if agent.get("password_hash"):
        if not req.old_password or not verify_password(req.old_password, agent["password_hash"]):
            raise HTTPException(status_code=400, detail="原密码错误")
    agents_collection.update_one(
        {"_id": agent["_id"]},
        {"$set": {"password_hash": hash_password(req.new_password),
                  "updated_at": datetime.now()}}
    )
    clear_password_fails(agent.get("phone", ""))
    print(f"\n[OK] 密码已设置/修改: {agent.get('name')} ({agent.get('phone')})")
    return {"success": True, "message": "密码设置成功"}


class ResetPasswordRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    code: str = Field(..., pattern=r"^\d{6}$")
    new_password: str = Field(..., min_length=PASSWORD_MIN, max_length=PASSWORD_MAX)

    @field_validator("new_password")
    @classmethod
    def _check_strength(cls, v):
        return validate_password_strength(v)


@auth_router.post("/auth/reset-password")
def reset_password(req: ResetPasswordRequest):
    """忘记密码:凭短信验证码重置(低频,适度用短信)。复用 send-sms-code 下发的码。"""
    stored_code = redis_client.get(f"sms:code:{req.phone}")
    if not stored_code:
        raise HTTPException(status_code=400, detail="验证码已过期,请重新获取")
    if stored_code != req.code:
        raise HTTPException(status_code=400, detail="验证码错误")

    agent = agents_collection.find_one({"phone": req.phone})
    if not agent:
        raise HTTPException(status_code=404, detail="手机号未注册")

    agents_collection.update_one(
        {"_id": agent["_id"]},
        {"$set": {"password_hash": hash_password(req.new_password),
                  "updated_at": datetime.now()}}
    )
    redis_client.delete(f"sms:code:{req.phone}")
    clear_password_fails(req.phone)  # 重置成功顺带解锁
    print(f"\n[OK] 密码已重置: {agent['name']} ({req.phone})")
    return {"success": True, "message": "密码重置成功,请用新密码登录"}


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., description="长期票 refresh_token")


class RefreshResponse(BaseModel):
    success: bool
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"


@auth_router.post("/auth/refresh", response_model=RefreshResponse)
def refresh_token_api(req: RefreshRequest):
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="登录已过期,请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if is_refresh_token_blacklisted(req.refresh_token):
        raise unauthorized

    try:
        payload = jwt.decode(req.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise unauthorized
        agent_id = payload.get("sub")
        if not agent_id:
            raise unauthorized
    except JWTError:
        raise unauthorized

    agent = agents_collection.find_one({"_id": ObjectId(agent_id)})
    if not agent:
        raise unauthorized
    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")

    blacklist_refresh_token(req.refresh_token, payload)

    new_access = create_access_token(agent_id)
    new_refresh = create_refresh_token(agent_id)
    print(f"\n🔄 Token 续期: {agent['name']} ({agent['phone']})")
    return RefreshResponse(
        success=True,
        access_token=new_access,
        refresh_token=new_refresh,
    )


class LogoutRequest(BaseModel):
    refresh_token: str = Field(..., description="当前的 refresh_token")


class LogoutResponse(BaseModel):
    success: bool
    message: str


@auth_router.post("/auth/logout", response_model=LogoutResponse)
def logout_api(req: LogoutRequest):
    try:
        payload = jwt.decode(
            req.refresh_token, SECRET_KEY, algorithms=[ALGORITHM]
        )
        if payload.get("type") == "refresh":
            blacklist_refresh_token(req.refresh_token, payload)
            print(f"\n🚪 退出登录: agent_id={payload.get('sub')}")
    except JWTError:
        pass
    return LogoutResponse(success=True, message="已退出登录")


class MeResponse(BaseModel):
    agent_id: str
    phone: str
    name: str
    store_name: str
    role: str
    status: str
    coop_verified: bool
    has_password: bool  # 前端据此提示用户"去设置密码"
    membership: dict    # {enforced, active, read_only, expires_at, days_left}


@auth_router.get("/me", response_model=MeResponse)
def get_me(agent: dict = Depends(get_current_agent)):
    return MeResponse(
        agent_id=str(agent["_id"]),
        phone=agent["phone"],
        name=agent["name"],
        store_name=agent.get("store_name", ""),
        role=agent.get("role", "agent"),
        status=agent.get("status", "active"),
        coop_verified=agent.get("coop_verified", False),
        has_password=bool(agent.get("password_hash")),
        membership=membership_info(agent),
    )


@auth_router.get("/membership")
def get_membership(agent: dict = Depends(get_current_agent)):
    """查询当前经纪人的会员状态(前端展示 + 过期横幅)。"""
    return {"success": True, "data": membership_info(agent)}
