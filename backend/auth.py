"""JWT 工具层 + 认证路由

拆自 main.py L182-512。
"""
import hashlib
import random
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import fakeredis
from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_HOURS, REFRESH_TOKEN_EXPIRE_DAYS, DEV_SMS_CODE
from database import agents_collection
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
        "avatar_url": "",
        "store_id": "",
        "store_name": req.store_name,
        "role": "agent",
        "status": "active",
        "coop_verified": False,
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
    )
