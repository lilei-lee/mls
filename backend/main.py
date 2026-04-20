"""
MLS 后端 - 第一个接口:发送短信验证码(Mock版)
作者:磊
日期:2026-04-19
"""
import random
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import fakeredis
from database import agents_collection, ping
from bson import ObjectId
from jose import jwt, JWTError
from listings import (
    CreateListingRequest,
    CreateListingResponse,
    create_listing,
    ensure_indexes,
    list_my_listings,
    count_my_listings,
    list_shared_listings,
    count_shared_listings,
    get_listing_by_id,
    update_listing,
    offline_listing,
    reactivate_listing,
    get_districts,
)
from showing_requests import (
    CreateShowingRequestBody,
    RejectRequestBody,
    ensure_showing_indexes,
    create_showing_request,
    approve_showing_request,
    reject_showing_request,
    get_request_by_id,
    list_received_requests,
    list_sent_requests,
    count_pending_received,
)
# 创建 FastAPI 应用实例
app = FastAPI(
    title="MLS 后端 API",
    description="张家口MLS经纪人系统 - 后端服务",
    version="0.1.0"
)
# 启动时测试数据库连接
@app.on_event("startup")
def startup_check():
    if ping():
        print("✓ MongoDB 连接正常")
    else:
        print("✗ MongoDB 连接失败!请检查服务是否启动")
    # 建立房源索引
    ensure_indexes()
    print("✓ 房源索引已建立")
    ensure_showing_indexes()
    print("✓ 带客申请索引已建立")

# 创建假 Redis(内存模拟,测试用)
redis_client = fakeredis.FakeStrictRedis(decode_responses=True)
# ==================== JWT 配置 ====================

SECRET_KEY = "3Qy1db3aKPG4cVCk3132qtE-m9w0OSb7W-BUbnM3RZs"  # 开发用,上线前换新的
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 2      # 短期票:2小时
REFRESH_TOKEN_EXPIRE_DAYS = 30     # 长期票:30天


def create_access_token(agent_id: str) -> str:
    """签发 Access Token,2小时有效,用于日常请求"""
    expire = datetime.utcnow() + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    payload = {
        "sub": agent_id,      # subject,这张票是谁的
        "exp": expire,        # expire,啥时候过期
        "type": "access",     # 票的种类
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(agent_id: str) -> str:
    """签发 Refresh Token,30天有效,用于换新的 Access Token"""
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": agent_id,
        "exp": expire,
        "type": "refresh",
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
# ==================== 认证检票员 ====================

# Bearer Token 检查器,会自动从 Header 里取 Authorization: Bearer xxx
security = HTTPBearer()


def get_current_agent(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    检票员:验证 Token → 从数据库查出当前登录的经纪人 → 返回经纪人信息
    任何接口加上 agent = Depends(get_current_agent),都会自动被保护
    """
    token = credentials.credentials  # 取出 Bearer 后面那串 token
    
    # 通用的"票不对"错误
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="身份验证失败,请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # 1. 解码 token,如果被篡改或签名不对,这里会抛异常
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # 2. 检查票的种类(access_token 才能用,refresh_token 不行)
        if payload.get("type") != "access":
            raise unauthorized
        
        # 3. 取出 agent_id
        agent_id = payload.get("sub")
        if not agent_id:
            raise unauthorized
    except JWTError:
        # token 过期、签名错误、格式错误等,统一走这里
        raise unauthorized
    
    # 4. 从 MongoDB 里查出经纪人信息
    agent = agents_collection.find_one({"_id": ObjectId(agent_id)})
    if not agent:
        raise unauthorized
    
    # 5. 检查账号状态
    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")
    
    return agent  # 返回整个经纪人文档,后面接口能直接用


# ==================== 数据模型 ====================

class SendSmsRequest(BaseModel):
    """发送验证码请求"""
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号")


class SendSmsResponse(BaseModel):
    """发送验证码响应"""
    success: bool
    message: str


# ==================== 接口 ====================

@app.get("/")
def root():
    """根路径 - 健康检查"""
    return {
        "service": "MLS 后端",
        "status": "running",
        "time": datetime.now().isoformat()
    }


@app.post("/api/v1/auth/send-sms-code", response_model=SendSmsResponse)
def send_sms_code(req: SendSmsRequest):
    """
    发送短信验证码(Mock版)
    
    - **phone**: 11位手机号(1开头,第二位3-9)
    - 生成6位随机验证码
    - 存入假Redis,5分钟过期
    - 打印到控制台(模拟发送短信)
    """
    # 频率限制:同一手机号60秒内只能请求一次
    rate_limit_key = f"sms:ratelimit:{req.phone}"
    if redis_client.exists(rate_limit_key):
        raise HTTPException(status_code=429, detail="请求过于频繁,请60秒后再试")
    
    # 生成6位随机验证码
    code = f"{random.randint(100000, 999999)}"
    
    # 存入假Redis,5分钟过期
    redis_client.setex(f"sms:code:{req.phone}", 300, code)
    
    # 频率限制60秒
    redis_client.setex(rate_limit_key, 60, "1")
    
    # 打印到控制台(模拟发送短信)
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
# ==================== 注册接口(真实数据库版) ====================

class RegisterRequest(BaseModel):
    """注册请求"""
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号")
    code: str = Field(..., pattern=r"^\d{6}$", description="6位验证码")
    name: str = Field(..., min_length=2, max_length=20, description="真实姓名")
    id_card: str = Field(..., pattern=r"^\d{17}[\dX]$", description="身份证号")
    store_name: str = Field(..., min_length=2, max_length=100, description="所属门店")


class RegisterResponse(BaseModel):
    """注册响应"""
    success: bool
    agent_id: str
    message: str


class RegisterResponse(BaseModel):
    """注册响应"""
    success: bool
    agent_id: str
    name: str
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    message: str


@app.post("/api/v1/auth/register", response_model=RegisterResponse)
def register(req: RegisterRequest):
    """
    经纪人注册 - 注册成功直接返回 token,自动登录
    
    流程:
      1. 校验验证码
      2. 检查手机号是否已注册
      3. 检查身份证号是否已注册
      4. 插入新经纪人到 MongoDB
      5. 签发 access_token + refresh_token(自动登录)
    """
    # 1. 校验验证码
    stored_code = redis_client.get(f"sms:code:{req.phone}")
    if not stored_code:
        raise HTTPException(status_code=400, detail="验证码已过期,请重新获取")
    if stored_code != req.code:
        raise HTTPException(status_code=400, detail="验证码错误")
    
    # 2. 检查手机号是否已注册
    existing = agents_collection.find_one({"phone": req.phone})
    if existing:
        raise HTTPException(status_code=409, detail="该手机号已注册")
    
    # 3. 检查身份证号是否已注册
    existing_id = agents_collection.find_one({"id_card": req.id_card})
    if existing_id:
        raise HTTPException(status_code=409, detail="该身份证号已注册")
    
    # 4. 插入新经纪人
    new_agent = {
        "phone": req.phone,
        "name": req.name,
        "id_card": req.id_card,
        "avatar_url": "",
        "store_id": "",
        "store_name": req.store_name,
        "role": "agent",              # 默认普通经纪人(老板后台手动提权)
        "status": "active",
        "coop_verified": False,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
        "last_login_at": datetime.now(),  # 注册即登录
        "devices": [],
        "wechat_unionid": None,
    }
    result = agents_collection.insert_one(new_agent)
    agent_id = str(result.inserted_id)
    
    # 5. 验证码用过即失效
    redis_client.delete(f"sms:code:{req.phone}")
    
    # 6. 签发两张 token(自动登录)
    access_token = create_access_token(agent_id)
    refresh_token = create_refresh_token(agent_id)
    
    print(f"\n✓ 新经纪人注册并自动登录: {req.name} ({req.phone})")
    
    return RegisterResponse(
        success=True,
        agent_id=agent_id,
        name=req.name,
        access_token=access_token,
        refresh_token=refresh_token,
        message=f"注册成功,欢迎 {req.name}!",
    )
# ==================== 登录接口 ====================

class LoginRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号")
    code: str = Field(..., pattern=r"^\d{6}$", description="6位验证码")


class LoginResponse(BaseModel):
    success: bool
    agent_id: str
    name: str
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    message: str


@app.post("/api/v1/auth/login", response_model=LoginResponse)
def login(req: LoginRequest):
    # 1. 校验验证码
    stored_code = redis_client.get(f"sms:code:{req.phone}")
    if not stored_code:
        raise HTTPException(status_code=400, detail="验证码已过期,请重新获取")
    if stored_code != req.code:
        raise HTTPException(status_code=400, detail="验证码错误")

    # 2. 查找经纪人
    agent = agents_collection.find_one({"phone": req.phone})
    if not agent:
        raise HTTPException(status_code=404, detail="手机号未注册,请先注册")

    # 3. 检查账号状态(预留,种子期宽松)
    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")

    # 4. 签发两张票
    agent_id = str(agent["_id"])
    access_token = create_access_token(agent_id)
    refresh_token = create_refresh_token(agent_id)

    # 5. 更新最后登录时间
    agents_collection.update_one(
        {"_id": agent["_id"]},
        {"$set": {"last_login_at": datetime.now()}}
    )

    # 6. 验证码用过即失效
    redis_client.delete(f"sms:code:{req.phone}")

    print(f"\n✓ 登录成功: {agent['name']} ({req.phone})")

    return LoginResponse(
        success=True,
        agent_id=agent_id,
        name=agent["name"],
        access_token=access_token,
        refresh_token=refresh_token,
        message=f"欢迎回来, {agent['name']}!"
    )

# ==================== 刷新 Token 接口 ====================

class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., description="长期票 refresh_token")


class RefreshResponse(BaseModel):
    success: bool
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"


@app.post("/api/v1/auth/refresh", response_model=RefreshResponse)
def refresh_token_api(req: RefreshRequest):
    """
    用 refresh_token 换一对新的 token
    - 每次调用会同时签发新的 access_token 和 refresh_token(Token Rotation)
    - 如果 refresh_token 已过期或无效,返回 401
    """
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="登录已过期,请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # 1. 解码,检查签名和过期时间
        payload = jwt.decode(req.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])

        # 2. 必须是 refresh 类型(不能拿 access_token 冒充)
        if payload.get("type") != "refresh":
            raise unauthorized

        # 3. 取出 agent_id
        agent_id = payload.get("sub")
        if not agent_id:
            raise unauthorized
    except JWTError:
        raise unauthorized

    # 4. 从数据库查经纪人,确认账号还健在
    agent = agents_collection.find_one({"_id": ObjectId(agent_id)})
    if not agent:
        raise unauthorized

    if agent.get("status") == "deleted":
        raise HTTPException(status_code=403, detail="账号已注销")
    if agent.get("status") == "banned":
        raise HTTPException(status_code=403, detail="账号已被禁用")

    # 5. 签发新的两张票
    new_access = create_access_token(agent_id)
    new_refresh = create_refresh_token(agent_id)

    print(f"\n🔄 Token 续期: {agent['name']} ({agent['phone']})")

    return RefreshResponse(
        success=True,
        access_token=new_access,
        refresh_token=new_refresh,
    )

# ==================== 受保护接口 ====================

class MeResponse(BaseModel):
    agent_id: str
    phone: str
    name: str
    store_name: str
    role: str
    status: str
    coop_verified: bool


@app.get("/api/v1/me", response_model=MeResponse)
def get_me(agent: dict = Depends(get_current_agent)):
    """
    获取当前登录经纪人的信息
    必须在 Header 里带上 Authorization: Bearer <access_token>
    """
    return MeResponse(
        agent_id=str(agent["_id"]),
        phone=agent["phone"],
        name=agent["name"],
        store_name=agent.get("store_name", ""),
        role=agent.get("role", "agent"),
        status=agent.get("status", "active"),
        coop_verified=agent.get("coop_verified", False),
    )

# ==================== 模块二:房源管理 ====================

@app.post("/api/v1/listings", response_model=CreateListingResponse)
def create_listing_api(
    req: CreateListingRequest,
    agent: dict = Depends(get_current_agent),
):
    """
    创建房源
    - 需要登录(带 Bearer Token)
    - 自动生成一户一码(小区+楼号+单元+门牌号)
    - 如果已存在,返回 409 告知已被谁录入
    """
    result = create_listing(req, agent)
    print(f"\n🏠 新房源录入: {req.community} {req.building}-{req.unit}-{req.room_no} by {agent['name']}")
    return CreateListingResponse(
        success=True,
        listing_id=result["listing_id"],
        house_code=result["house_code"],
        message=f"录入成功!一户一码: {result['house_code']}",
    )

class ListingListResponse(BaseModel):
    success: bool
    total: int
    items: list


@app.get("/api/v1/listings/mine", response_model=ListingListResponse)
def get_my_listings_api(
    skip: int = 0,
    limit: int = 20,
    agent: dict = Depends(get_current_agent),
):
    """
    获取当前登录经纪人自己录入的所有房源
    - skip:跳过多少条(分页用)
    - limit:返回多少条(默认 20)
    """
    items = list_my_listings(agent["_id"], skip=skip, limit=limit)
    total = count_my_listings(agent["_id"])
    return ListingListResponse(success=True, total=total, items=items)

@app.get("/api/v1/listings/shared", response_model=ListingListResponse)
def get_shared_listings_api(
    skip: int = 0,
    limit: int = 20,
    agent: dict = Depends(get_current_agent),
):
    """
    获取共享房源库(匿名):其他经纪人录入的在售房源
    - 自动过滤掉登录者自己的房源
    - 不返回任何录入人身份信息(浏览阶段匿名)
    """
    items = list_shared_listings(agent["_id"], skip=skip, limit=limit)
    total = count_shared_listings(agent["_id"])
    return ListingListResponse(success=True, total=total, items=items)

# ==================== 单条房源接口 ====================

class UpdateListingRequest(BaseModel):
    """
    更新房源请求 - 只允许修改这些字段
    全部 Optional:前端可以只传想改的字段,不传的字段保持原值
    """
    rooms: int | None = None
    halls: int | None = None
    bathrooms: int | None = None
    floor: int | None = None
    total_floor: int | None = None
    orientation: str | None = None
    price_wan: float | None = None
    remarks: str | None = None
    # 段 8 新增:照片字段
    cover_thumbnail: str | None = None
    photos: list | None = None


@app.get("/api/v1/listings/{listing_id}")
def get_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """获取单条房源详情"""
    doc = get_listing_by_id(listing_id)
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    return {"success": True, "data": doc}


@app.patch("/api/v1/listings/{listing_id}")
def update_listing_api(
    listing_id: str,
    req: UpdateListingRequest,
    agent: dict = Depends(get_current_agent),
):
    """更新房源(仅本人)"""
    update_fields = req.model_dump(exclude_unset=True)  # 只取前端真的传了的字段
    doc = update_listing(listing_id, update_fields, agent["_id"])
    print(f"\n🏠 房源更新: {doc['community']} {doc['building']}-{doc['unit']}-{doc['room_no']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.delete("/api/v1/listings/{listing_id}")
def offline_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """下架房源(软删除,仅本人)"""
    doc = offline_listing(listing_id, agent["_id"])
    print(f"\n🚫 房源下架: {doc['community']} {doc['building']}-{doc['unit']}-{doc['room_no']} by {agent['name']}")
    return {"success": True, "data": doc}

@app.post("/api/v1/listings/{listing_id}/reactivate")
def reactivate_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """重新上架(把 offline 状态改回 on_sale)"""
    doc = reactivate_listing(listing_id, agent["_id"])
    print(f"\n♻️  房源重新上架: {doc['community']} {doc['building']}-{doc['unit']}-{doc['room_no']} by {agent['name']}")
    return {"success": True, "data": doc}

@app.get("/api/v1/listings/meta/districts")
def get_districts_api(agent: dict = Depends(get_current_agent)):
    """获取张家口行政区字典(用于录入页下拉、筛选抽屉)"""
    return {"success": True, "districts": get_districts()}

# ==================== 模块四:带客协作 ====================

@app.post("/api/v1/showing-requests")
def create_showing_request_api(
    req: CreateShowingRequestBody,
    agent: dict = Depends(get_current_agent),
):
    """BA 发起带客申请"""
    result = create_showing_request(req, agent)
    print(f"\n👀 新带客申请: 客户{req.customer_surname} by {agent['name']}")
    return {"success": True, **result}


@app.get("/api/v1/showing-requests/received")
def list_received_requests_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    """LA 视角:我收到的带客申请(别人向我房源申请)"""
    items, total = list_received_requests(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/showing-requests/sent")
def list_sent_requests_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    """BA 视角:我发出的带客申请"""
    items, total = list_sent_requests(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/showing-requests/pending-count")
def pending_count_api(agent: dict = Depends(get_current_agent)):
    """工作台角标:待我审批的数量"""
    count = count_pending_received(agent["_id"])
    return {"success": True, "count": count}


@app.get("/api/v1/showing-requests/{request_id}")
def get_showing_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    """查申请详情(按角色自动控制身份可见性)"""
    doc = get_request_by_id(request_id, agent["_id"])
    return {"success": True, "data": doc}


@app.post("/api/v1/showing-requests/{request_id}/approve")
def approve_showing_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    """LA 审批通过"""
    doc = approve_showing_request(request_id, agent["_id"])
    print(f"\n✅ 审批通过: 客户{doc['customer_surname']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.post("/api/v1/showing-requests/{request_id}/reject")
def reject_showing_request_api(
    request_id: str,
    body: RejectRequestBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 审批拒绝"""
    doc = reject_showing_request(request_id, body, agent["_id"])
    print(f"\n❌ 审批拒绝: 客户{doc['customer_surname']} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}