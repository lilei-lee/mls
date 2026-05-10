"""
MLS 后端 - 所有接口入口
作者:磊
日期:2026-04-19
"""
import hashlib
import random
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Depends, status, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import fakeredis
from database import agents_collection, ping, db
from bson import ObjectId
from jose import jwt, JWTError
from listings import (
    CreateListingRequest,
    PostListingRequest,
    _extract_physical_attrs,
    SyncPhysicalBody,
    CreateListingResponse,
    MarkDepositPaidBody,
    MarkTransactionOngoingBody,
    RollbackStatusBody,
    create_listing,
    ensure_indexes,
    list_my_listings,
    count_my_listings,
    list_shared_listings,
    count_shared_listings,
    get_listing_by_id,
    sync_physical_to_dict,
    update_listing,
    offline_listing,
    reactivate_listing,
    get_showings_summary,
    get_districts,
    mark_listing_deposit_paid,
    mark_listing_transaction_ongoing,
    rollback_listing_to_on_sale,
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
    count_my_sent_recent_changes,
)
from showings import (
    CreateShowingBody,
    RejectShowingBody,
    ensure_showings_indexes,
    submit_showing,
    get_showing_by_id,
    get_showing_by_request,
    confirm_showing,
    reject_showing,
    list_pending_confirm,
    count_pending_confirm,
)
from communities import (
    CreateCommunityBody,
    ensure_communities_indexes,
    search_communities,
    create_community,
    get_community_by_id,
    get_community_detail,
    get_community_listings,
    get_community_deals,
)
from transactions import (
    InitiateTransactionBody,
    LaConfirmTransactionBody,
    LaRejectTransactionBody,
    UpdateMyTransactionBody,
    LaUpdateMySubmissionBody,
    CancelTransactionBody,
    ensure_transactions_indexes,
    initiate_transaction,
    la_confirm_transaction,
    la_reject_transaction,
    update_my_transaction,
    update_my_submission_la,
    cancel_transaction,
    get_by_id as get_transaction_by_id,
    get_by_showing as get_transaction_by_showing,
    list_pending_for_la,
    count_pending_for_la,
)
from settlements import (
    LaMarkPaidBody,
    ensure_settlements_indexes,
    la_mark_paid,
    get_by_id as get_settlement_by_id,
    list_pending_for_me as list_pending_settlements_for_me,
    count_pending_for_me as count_pending_settlements_for_me,
)
from scheduler import start_scheduler, stop_scheduler
from customers import (
    CreateCustomerRequest,
    UpdateCustomerRequest,
    AddMemoRequest,
    ensure_customers_indexes,
    create_customer,
    list_my_customers,
    count_my_customers,
    get_customer_by_id,
    update_customer,
    add_memo,
    close_customer,
    get_customer_timeline,
    can_direct_showing,
    DirectShowingRequest,
    create_direct_showing,
)
from collaborations import list_my_collaborations

app = FastAPI(
    title="MLS 后端 API",
    description="张家口MLS经纪人系统 - 后端服务",
    version="0.1.0"
)


# V2.5: Q&A 问答系统
from qna import qna_router as _qna_router
app.include_router(_qna_router)

@app.on_event("startup")
def startup_check():
    if ping():
        print("[OK] MongoDB connected")
    else:
        print("[FAIL] MongoDB connection failed!")
    ensure_indexes()
    print("[OK] 房源索引已建立")
    ensure_showing_indexes()
    print("[OK] 带客申请索引已建立")
    ensure_showings_indexes()
    print("[OK] 带看记录索引已建立")
    ensure_communities_indexes()
    print("[OK] 小区库索引已建立")
    ensure_transactions_indexes()
    print("[OK] 成交记录索引已建立")
    ensure_settlements_indexes()
    print("[OK] 奖金结算索引已建立")
    ensure_customers_indexes()
    print("[OK] 客户档案索引已建立")
    start_scheduler()


@app.on_event("shutdown")
def shutdown_hook():
    stop_scheduler()


redis_client = fakeredis.FakeStrictRedis(decode_responses=True)

# ==================== JWT 配置 ====================

SECRET_KEY = "3Qy1db3aKPG4cVCk3132qtE-m9w0OSb7W-BUbnM3RZs"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 2
REFRESH_TOKEN_EXPIRE_DAYS = 30


def create_access_token(agent_id: str) -> str:
    expire = datetime.utcnow() + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    payload = {"sub": agent_id, "exp": expire, "type": "access"}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(agent_id: str) -> str:
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


# ==================== 数据模型 ====================

class SendSmsRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号")


class SendSmsResponse(BaseModel):
    success: bool
    message: str


@app.get("/")
def root():
    return {
        "service": "MLS 后端",
        "status": "running",
        "time": datetime.now().isoformat()
    }


@app.post("/api/v1/auth/send-sms-code", response_model=SendSmsResponse)
def send_sms_code(req: SendSmsRequest):
    rate_limit_key = f"sms:ratelimit:{req.phone}"
    if redis_client.exists(rate_limit_key):
        raise HTTPException(status_code=429, detail="请求过于频繁,请60秒后再试")
    code = "123456"  # 开发期固定，方便测试。生产前必须改回 random.randint(100000, 999999)
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


@app.post("/api/v1/auth/register", response_model=RegisterResponse)
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


@app.post("/api/v1/auth/login", response_model=LoginResponse)
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


@app.post("/api/v1/auth/refresh", response_model=RefreshResponse)
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


@app.post("/api/v1/auth/logout", response_model=LogoutResponse)
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


@app.get("/api/v1/me", response_model=MeResponse)
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


# ==================== 模块二:房源管理 ====================

@app.post("/api/v1/listings", response_model=CreateListingResponse)
def create_listing_api(
    req: PostListingRequest,
    agent: dict = Depends(get_current_agent),
):
    physical_attrs = _extract_physical_attrs(req)
    result = create_listing(req, physical_attrs, agent)
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
    items = list_my_listings(agent["_id"], skip=skip, limit=limit)
    total = count_my_listings(agent["_id"])
    return ListingListResponse(success=True, total=total, items=items)


def _parse_csv(val: str | None) -> list[str] | None:
    if not val:
        return None
    items = [v.strip() for v in val.split(",") if v.strip()]
    return items or None


@app.get("/api/v1/listings/shared", response_model=ListingListResponse)
def get_shared_listings_api(
    skip: int = 0,
    limit: int = 20,
    new_today: bool = False,
    # V2.2 #1: 5 类新筛选
    sale_points: str | None = Query(None, description="卖点标签,逗号分隔 AND 语义"),
    objective_features: str | None = Query(None, description="客观特征,逗号分隔 AND 语义"),
    decoration: str | None = Query(None, description="装修(单选枚举)"),
    heating_type: str | None = Query(None, description="供暖(单选枚举)"),
    bld_year_min: int | None = Query(None, description="楼龄下限"),
    bld_year_max: int | None = Query(None, description="楼龄上限"),
    community_id: str | None = Query(None, description="小区ID(MLS侧,按小区过滤在售房源)"),
    # V2.2 #2: 新增朝向 + 户型结构筛选
    orientation: str | None = Query(None, description="朝向(朝东/朝西/朝南/朝北)"),
    house_structure: str | None = Query(None, description="户型结构(平层/复式/Loft/跃层/错层/跃复一体)"),
    sort: str | None = Query(None, description="排序:default/latest/price_asc/price_desc/unit_price_asc/area_desc"),
    agent: dict = Depends(get_current_agent),
):
    items, total = list_shared_listings(
        agent["_id"], skip=skip, limit=limit, new_today=new_today,
        sale_points=_parse_csv(sale_points),
        objective_features=_parse_csv(objective_features),
        decoration=decoration,
        heating_type=heating_type,
        bld_year_min=bld_year_min,
        bld_year_max=bld_year_max,
        community_id=community_id,
        orientation=orientation,
        house_structure=house_structure,
        sort=sort,
    )
    return ListingListResponse(success=True, total=total, items=items)


class UpdateListingRequest(BaseModel):
    orientation: str | None = None
    price_wan: float | None = None
    bonus_yuan: int | None = None
    cover_thumbnail: str | None = None
    photos: list | None = None
    # V2.2 #1: remark 拆为 public_remarks + agent_remarks
    public_remarks: str | None = None
    agent_remarks: str | None = None
    showing_instructions: str | None = None
    sale_points: list | None = None


@app.get("/api/v1/listings/meta/districts")
def get_districts_api(agent: dict = Depends(get_current_agent)):
    return {"success": True, "districts": get_districts()}


# ⚠️ 具体路径必须注册在 {listing_id} 之前

@app.post("/api/v1/listings/{listing_id}/mark-deposit-paid")
def mark_deposit_paid_api(
    listing_id: str,
    body: MarkDepositPaidBody,
    agent: dict = Depends(get_current_agent),
):
    """V5:标记定金已付"""
    doc = mark_listing_deposit_paid(listing_id, body, agent["_id"])
    print(f"\n💰 房源标记定金已付: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.post("/api/v1/listings/{listing_id}/mark-transaction-ongoing")
def mark_transaction_ongoing_api(
    listing_id: str,
    body: MarkTransactionOngoingBody,
    agent: dict = Depends(get_current_agent),
):
    """V5:标记成交进行中"""
    doc = mark_listing_transaction_ongoing(listing_id, body, agent["_id"])
    print(f"\n📝 房源标记成交进行中: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.post("/api/v1/listings/{listing_id}/rollback-to-on-sale")
def rollback_to_on_sale_api(
    listing_id: str,
    body: RollbackStatusBody,
    agent: dict = Depends(get_current_agent),
):
    """V5:回退到在售"""
    doc = rollback_listing_to_on_sale(listing_id, body, agent["_id"])
    print(f"\n↩️  房源回退到在售: {doc['community']} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


@app.post("/api/v1/listings/{listing_id}/reactivate")
def reactivate_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = reactivate_listing(listing_id, agent["_id"])
    print(f"\n♻️  房源重新上架: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.post("/api/v1/listings/{listing_id}/sync-physical")
def sync_listing_physical_api(
    listing_id: str,
    body: SyncPhysicalBody = SyncPhysicalBody(),
    agent: dict = Depends(get_current_agent),
):
    return sync_physical_to_dict(listing_id, body, agent["_id"])


@app.get("/api/v1/listings/{listing_id}/showings-summary")
def get_showings_summary_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """V2.2 #3: LA 查看自己房源的所有带看记录"""
    return {"success": True, "items": get_showings_summary(listing_id, agent["_id"])}


@app.get("/api/v1/listings/{listing_id}")
def get_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_listing_by_id(listing_id, viewer_id=agent["_id"])
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    return {"success": True, "data": doc}


@app.patch("/api/v1/listings/{listing_id}")
def update_listing_api(
    listing_id: str,
    req: UpdateListingRequest,
    agent: dict = Depends(get_current_agent),
):
    update_fields = req.model_dump(exclude_unset=True)
    doc = update_listing(listing_id, update_fields, agent["_id"])
    print(f"\n🏠 房源更新: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.delete("/api/v1/listings/{listing_id}")
def offline_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = offline_listing(listing_id, agent["_id"])
    print(f"\n🚫 房源下架: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


# ==================== 模块四:带客协作 ====================

@app.post("/api/v1/showing-requests")
def create_showing_request_api(
    req: CreateShowingRequestBody,
    agent: dict = Depends(get_current_agent),
):
    result = create_showing_request(req, agent)
    print(f"\n👀 新带客申请: 客户{req.customer_surname} by {agent['name']}")
    return {"success": True, **result}


@app.get("/api/v1/showing-requests/received")
def list_received_requests_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    items, total = list_received_requests(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/showing-requests/sent")
def list_sent_requests_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    items, total = list_sent_requests(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/showing-requests/pending-count")
def pending_count_api(agent: dict = Depends(get_current_agent)):
    count = count_pending_received(agent["_id"])
    return {"success": True, "count": count}


@app.get("/api/v1/showing-requests/{request_id}")
def get_showing_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_request_by_id(request_id, agent["_id"])
    return {"success": True, "data": doc}


@app.post("/api/v1/showing-requests/{request_id}/approve")
def approve_showing_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = approve_showing_request(request_id, agent["_id"])
    print(f"\n✅ 审批通过: 客户{doc['customer_surname']} by {agent['name']}")
    return {"success": True, "data": doc}


@app.post("/api/v1/showing-requests/{request_id}/reject")
def reject_showing_request_api(
    request_id: str,
    body: RejectRequestBody,
    agent: dict = Depends(get_current_agent),
):
    doc = reject_showing_request(request_id, body, agent["_id"])
    print(f"\n❌ 审批拒绝: 客户{doc['customer_surname']} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


# ==================== 模块四续集:带看确认 ====================

@app.post("/api/v1/showings")
def submit_showing_api(
    body: CreateShowingBody,
    agent: dict = Depends(get_current_agent),
):
    result = submit_showing(body, agent)
    print(f"\n📸 新带看记录: showing_id={result['showing_id']} by {agent['name']}")
    return {"success": True, **result}


@app.get("/api/v1/showings/pending-confirm")
def list_pending_confirm_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    items, total = list_pending_confirm(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/showings/pending-confirm-count")
def pending_confirm_count_api(agent: dict = Depends(get_current_agent)):
    count = count_pending_confirm(agent["_id"])
    return {"success": True, "count": count}


@app.get("/api/v1/showings/by-request/{request_id}")
def get_showing_by_request_api(
    request_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_showing_by_request(request_id, agent["_id"])
    return {"success": True, "data": doc}


@app.post("/api/v1/showings/{showing_id}/confirm")
def confirm_showing_api(
    showing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = confirm_showing(showing_id, agent["_id"])
    print(f"\n✔️  带看已确认: showing_id={showing_id} by {agent['name']}")
    return {"success": True, "data": doc}


@app.post("/api/v1/showings/{showing_id}/reject")
def reject_showing_api(
    showing_id: str,
    body: RejectShowingBody,
    agent: dict = Depends(get_current_agent),
):
    doc = reject_showing(showing_id, body, agent["_id"])
    print(f"\n⏪ 带看驳回: showing_id={showing_id} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


# 具体路径必须先于 {showing_id} 注册(坑 3: FastAPI 路由顺序)
# 否则 "can-direct" / "direct" 会被 {showing_id} 吞掉当 OID 解析
@app.get("/api/v1/showings/can-direct")
def api_can_direct_showing(
    listing_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """检查能否对某房直接发起带看(熟人专用)"""
    data = can_direct_showing(str(current_agent["_id"]), listing_id)
    return {"success": True, "data": data}

@app.post("/api/v1/showings/direct")
def api_create_direct_showing(
    req: DirectShowingRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """直接发起带看(跳过申请) · 前置:对这套房历史有 approved 申请"""
    data = create_direct_showing(str(current_agent["_id"]), req)
    return {"success": True, "data": data}

@app.get("/api/v1/showings/{showing_id}")
def get_showing_api(
    showing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_showing_by_id(showing_id, agent["_id"])
    return {"success": True, "data": doc}


# ==================== 模块五:成交确认(节点 ⑤)====================
# ⚠️ 具体路径必须先注册

@app.post("/api/v1/transactions")
def initiate_transaction_api(
    body: InitiateTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """BA 发起成交确认"""
    result = initiate_transaction(body, agent)
    print(f"\n💰 新成交确认发起: tx={result['transaction_id']} by {agent['name']}")
    return {"success": True, **result}


@app.get("/api/v1/transactions/pending-la")
def list_pending_la_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    """LA 待我确认的成交列表"""
    items, total = list_pending_for_la(agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/transactions/pending-la-count")
def pending_la_count_api(agent: dict = Depends(get_current_agent)):
    """工作台角标"""
    count = count_pending_for_la(agent["_id"])
    return {"success": True, "count": count}


@app.get("/api/v1/transactions/by-showing/{showing_id}")
def get_transaction_by_showing_api(
    showing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """按带看查成交(可能 null)"""
    doc = get_transaction_by_showing(showing_id, agent["_id"])
    return {"success": True, "data": doc}


@app.post("/api/v1/transactions/{transaction_id}/la-confirm")
def la_confirm_transaction_api(
    transaction_id: str,
    body: LaConfirmTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 独立填价 + 自动比对"""
    doc = la_confirm_transaction(transaction_id, body, agent["_id"])
    if doc["status"] == "confirmed":
        print(f"\n🎉 成交确认通过: tx={transaction_id} by {agent['name']}")
    else:
        print(f"\n⚠️  成交确认价格不一致自动驳回: tx={transaction_id}")
    return {"success": True, "data": doc}


@app.post("/api/v1/transactions/{transaction_id}/la-reject")
def la_reject_transaction_api(
    transaction_id: str,
    body: LaRejectTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 手动驳回"""
    doc = la_reject_transaction(transaction_id, body, agent["_id"])
    print(f"\n❌ 成交手动驳回: tx={transaction_id} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


@app.patch("/api/v1/transactions/{transaction_id}/my-submission")
def update_my_transaction_api(
    transaction_id: str,
    body: UpdateMyTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """BA/LA 修改自己的填报并重提

    根据 caller 身份自动路由:
    - BA: 改 ba_deal_price_yuan / ba_deal_date,清掉 LA 旧值,重提 pending_la_confirm
    - LA: 改 la_deal_price_yuan / la_deal_date,复用比对逻辑
    """
    # 先查 doc 判身份(无法从 body 区分 BA/LA)
    tx = db["transactions"].find_one({"_id": ObjectId(transaction_id)})
    if not tx:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if agent["_id"] == tx["ba_agent_id"]:
        doc = update_my_transaction(transaction_id, body, agent["_id"])
        print(f"\n✏️  成交记录修改重提(BA): tx={transaction_id} by {agent['name']}")
    elif agent["_id"] == tx["la_agent_id"]:
        if body.deal_price_yuan is None or body.deal_date is None:
            raise HTTPException(
                status_code=400,
                detail="修改填报需同时提供 deal_price_yuan 和 deal_date",
            )
        la_body = LaUpdateMySubmissionBody(
            la_deal_price_yuan=body.deal_price_yuan,
            la_deal_date=body.deal_date,
        )
        doc = update_my_submission_la(transaction_id, la_body, agent["_id"])
        print(f"\n✏️  成交记录修改重提(LA): tx={transaction_id} by {agent['name']}")
    else:
        raise HTTPException(status_code=403, detail="无权修改此成交记录")
    return {"success": True, "data": doc}


@app.post("/api/v1/transactions/{transaction_id}/cancel")
def cancel_transaction_api(
    transaction_id: str,
    body: CancelTransactionBody,
    agent: dict = Depends(get_current_agent),
):
    """BA 撤回"""
    doc = cancel_transaction(transaction_id, body, agent["_id"])
    print(f"\n🚫 成交已撤回: tx={transaction_id} by {agent['name']}")
    return {"success": True, "data": doc}


@app.get("/api/v1/transactions/{transaction_id}")
def get_transaction_api(
    transaction_id: str,
    agent: dict = Depends(get_current_agent),
):
    """成交详情(BA 或 LA)"""
    doc = get_transaction_by_id(transaction_id, agent["_id"])
    return {"success": True, "data": doc}


# ==================== 工作台 Dashboard ====================

@app.get("/api/v1/dashboard/summary")
def dashboard_summary_api(agent: dict = Depends(get_current_agent)):
    """工作台 5 个数字"""
    agent_id = agent["_id"]

    my_on_sale = db["listings"].count_documents({
        "owner_agent_id": agent_id,
        "status": "on_sale",
    })

    # 共享库统计:总数 + 今日新增
    shared_total = count_shared_listings(agent_id, new_today=False)
    shared_new_today = count_shared_listings(agent_id, new_today=True)

    pending_approval = count_pending_received(agent_id)
    pending_confirm_showing = count_pending_confirm(agent_id)
    pending_confirm_transaction = count_pending_for_la(agent_id)
    pending_settlement = count_pending_settlements_for_me(agent_id)
    my_sent_recent_changes = count_my_sent_recent_changes(agent_id)

    return {
        "success": True,
        "data": {
            "my_on_sale_count": my_on_sale,
            "shared_total_count": shared_total,
            "shared_new_today_count": shared_new_today,
            "pending_approval_count": pending_approval,
            "pending_confirm_showing_count": pending_confirm_showing,
            "pending_confirm_transaction_count": pending_confirm_transaction,
            "pending_settlement_count": pending_settlement,
            "my_sent_recent_changes_count": my_sent_recent_changes,
        },
    }


# ==================== 模块三补强:小区库 ====================

@app.get("/api/v1/communities/search")
def search_communities_api(
    q: str = "",
    district: str | None = None,
    limit: int = 10,
    agent: dict = Depends(get_current_agent),
):
    items = search_communities(q, district, limit)
    return {"success": True, "items": items}


@app.post("/api/v1/communities")
def create_community_api(
    body: CreateCommunityBody,
    agent: dict = Depends(get_current_agent),
):
    result = create_community(body, agent)
    print(f"\n🏘️  新小区: {body.name} ({body.district}) by {agent['name']}")
    return {"success": True, **result, "message": "小区已添加"}


@app.get("/api/v1/communities/{community_id}")
def get_community_api(
    community_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_community_by_id(community_id)
    return {"success": True, "data": doc}


@app.get("/api/v1/communities/{community_id}/detail")
def get_community_detail_api(community_id: str, agent: dict = Depends(get_current_agent)):
    """V2.2 #4: 社区详情(档案+统计+预览)"""
    return {"success": True, "data": get_community_detail(community_id)}


@app.get("/api/v1/communities/{community_id}/listings")
def get_community_listings_api(
    community_id: str,
    room: int | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    agent: dict = Depends(get_current_agent),
):
    """V2.2 #4: 社区在售房源分页"""
    return {"success": True, "data": get_community_listings(community_id, room=room, page=page, page_size=page_size)}


@app.get("/api/v1/communities/{community_id}/deals")
def get_community_deals_api(community_id: str, agent: dict = Depends(get_current_agent)):
    """V2.2 #4: 社区成交记录(V3 占位)"""
    return {"success": True, "data": get_community_deals(community_id)}

    # ==================== 奖金结算(节点 ⑥) ====================


@app.get("/api/v1/settlements/pending-my")
def list_pending_settlements_api(
    skip: int = 0,
    limit: int = 50,
    agent: dict = Depends(get_current_agent),
):
    """待我处理的奖金结算单(LA 待付 / BA 待确认,合并返回)"""
    items, total = list_pending_settlements_for_me(
        agent["_id"], skip=skip, limit=limit)
    return {"success": True, "total": total, "items": items}


@app.get("/api/v1/settlements/pending-my-count")
def pending_settlements_count_api(
    agent: dict = Depends(get_current_agent),
):
    """工作台"待我操作奖金"角标数"""
    count = count_pending_settlements_for_me(agent["_id"])
    return {"success": True, "count": count}


@app.post("/api/v1/settlements/{settlement_id}/la-mark-paid")
def la_mark_paid_api(
    settlement_id: str,
    body: LaMarkPaidBody,
    agent: dict = Depends(get_current_agent),
):
    """LA 标记"我已付款" → pending_payment 转 pending_receipt"""
    doc = la_mark_paid(settlement_id, body, agent["_id"])
    return {"success": True, "data": doc}


@app.get("/api/v1/settlements/{settlement_id}")
def get_settlement_api(
    settlement_id: str,
    agent: dict = Depends(get_current_agent),
):
    """结算单详情(viewer-aware)"""
    doc = get_settlement_by_id(settlement_id, agent["_id"])
    return {"success": True, "data": doc}

# ==================== 模块:客户管理(Day 10) ====================

@app.post("/api/v1/customers")
def api_create_customer(
    req: CreateCustomerRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """BA 创建一个新客户"""
    data = create_customer(str(current_agent["_id"]), req)
    return {"success": True, "data": data}


@app.get("/api/v1/customers/mine")
def api_list_my_customers(
    current_agent: dict = Depends(get_current_agent),
):
    """BA 查自己的客户列表"""
    data = list_my_customers(str(current_agent["_id"]))
    return {"success": True, "data": {"items": data, "total": len(data)}}

@app.get("/api/v1/customers/{customer_id}")
def api_get_customer(
    customer_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """查客户详情"""
    data = get_customer_by_id(str(current_agent["_id"]), customer_id)
    return {"success": True, "data": data}


@app.patch("/api/v1/customers/{customer_id}")
def api_update_customer(
    customer_id: str,
    req: UpdateCustomerRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """更新客户基础信息"""
    data = update_customer(str(current_agent["_id"]), customer_id, req)
    return {"success": True, "data": data}


@app.post("/api/v1/customers/{customer_id}/memo")
def api_add_memo(
    customer_id: str,
    req: AddMemoRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """添加跟进记录"""
    data = add_memo(str(current_agent["_id"]), customer_id, req)
    return {"success": True, "data": data}


@app.patch("/api/v1/customers/{customer_id}/close")
def api_close_customer(
    customer_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """标记客户为已结单"""
    data = close_customer(str(current_agent["_id"]), customer_id)
    return {"success": True, "data": data}


@app.get("/api/v1/customers/{customer_id}/timeline")
def api_get_customer_timeline(
    customer_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """查客户时间线(关联的协作事件)"""
    data = get_customer_timeline(str(current_agent["_id"]), customer_id)
    return {"success": True, "data": data}


# ==================== 模块:工作台 Day 11 增强 ====================

@app.get("/api/v1/dashboard/todos")
def api_dashboard_todos(
    current_agent: dict = Depends(get_current_agent),
):
    """工作台 · 逐条待办列表(最多 5 类,每类最多 5 条)

    5 类:
    1. 待我审批的申请(LA 视角)
    2. 待我确认的带看(LA 视角)
    3. 待我确认的成交(LA 视角)
    4. 待我操作的奖金(LA / BA 都可能)
    5. 成交被驳回(BA 视角)
    """
    agent_id = current_agent["_id"]
    todos = []

    # --- 1. 待审批申请(LA) ---
    pending_reqs = list(db["showing_requests"].find(
        {"listing_agent_id": agent_id, "status": "pending"},
    ).sort("created_at", -1).limit(5))
    
    for r in pending_reqs:
        snapshot = r.get("listing_snapshot", {})
        todos.append({
            "type": "approval",
            "priority": "high",
            "icon": "person_add",
            "title": f"{r.get('buyer_agent_name', '同行')}申请带看{snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": f"客户:{r.get('customer_surname','')}{'先生' if r.get('customer_gender')=='male' else '女士'} · {r.get('requirements','')}",
            "action_route": f"/showing-request/{str(r['_id'])}",
            "created_at": r["created_at"].isoformat() if r.get("created_at") else None,
        })

    # --- 2. 待确认带看(LA) ---
    pending_shows = list(db["showings"].find(
        {"la_agent_id": agent_id, "status": "pending_confirm"},
    ).sort("created_at", -1).limit(5))

    for s in pending_shows:
        snapshot = s.get("listing_snapshot", {})
        todos.append({
            "type": "showing_confirm",
            "priority": "high",
            "icon": "rate_review",
            "title": f"带看待确认 · {snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": f"客户:{s.get('customer_surname','')}{'先生' if s.get('customer_gender')=='male' else '女士'} · {s.get('photo_count',0)} 张照片",
            "action_route": f"/showing/{str(s['_id'])}/confirm",
            "created_at": s["created_at"].isoformat() if s.get("created_at") else None,
        })

    # --- 3. 待确认成交(LA) ---
    pending_txs = list(db["transactions"].find(
        {"la_agent_id": agent_id, "status": "pending_la_confirm"},
    ).sort("created_at", -1).limit(5))

    for t in pending_txs:
        snapshot = t.get("listing_snapshot", {})
        todos.append({
            "type": "transaction_confirm",
            "priority": "high",
            "icon": "gavel",
            "title": f"成交待确认 · {snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": "请独立填写成交价格,与 BA 一致方可通过",
            "action_route": f"/transaction/{str(t['_id'])}",
            "created_at": t["created_at"].isoformat() if t.get("created_at") else None,
        })

    # --- 4. 待操作奖金(LA 付款 / BA 收款,都算) ---
    pending_settlements = list(db["settlements"].find({
        "$or": [
            {"la_agent_id": agent_id, "status": "pending_payment"},
            {"ba_agent_id": agent_id, "status": "pending_receipt"},
        ],
    }).sort("created_at", -1).limit(5))

    for stl in pending_settlements:
        my_role = "la" if stl.get("la_agent_id") == agent_id else "ba"
        action_text = "待你标记已付" if my_role == "la" else "待你确认收款"
        snapshot = stl.get("listing_snapshot", {})
        bonus = stl.get("bonus_yuan", 0)
        todos.append({
            "type": "settlement",
            "priority": "normal",
            "icon": "monetization_on",
            "title": f"奖金 ¥{bonus} · {snapshot.get('community','')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": action_text,
            "action_route": f"/settlements/{str(stl['_id'])}",
            "created_at": stl["created_at"].isoformat() if stl.get("created_at") else None,
        })

    # --- 5. 成交被驳回(BA) ---
    rejected_txs = list(db["transactions"].find(
        {"ba_agent_id": agent_id, "status": "rejected"},
    ).sort("created_at", -1).limit(5))

    for t in rejected_txs:
        snapshot = t.get("listing_snapshot", {})
        reject_reason = t.get("reject_reason", "")
        todos.append({
            "type": "transaction_rejected",
            "priority": "high",
            "icon": "edit",
            "title": f"成交确认被驳回,待修改重提 · {snapshot.get('community', '')} {snapshot.get('building','')}-{snapshot.get('unit','')}-{snapshot.get('room_no','')}",
            "subtitle": reject_reason or "请修改后重新提交",
            "action_route": f"/transaction/{str(t['_id'])}",
            "created_at": t["created_at"].isoformat() if t.get("created_at") else None,
        })

    # --- 6. 待回答的问题(LA) ---
    pending_qna = list(db["qna_threads"].find(
        {"answerer_id": str(agent_id), "status": "pending"},
    ).sort("question_at", -1).limit(5))

    for q in pending_qna:
        listing = db["listings"].find_one({"_id": ObjectId(q["listing_id"])}) if q.get("listing_id") else None
        comm = listing.get("community", "") if listing else ""
        todos.append({
            "type": "answer_pending",
            "priority": "medium",
            "icon": "help_circle",
            "title": f'{q.get("asker_anonymous_name", "同行")} 对你的{comm}提问',
            "subtitle": f'问:{q["question"][:40]}{"..." if len(q.get("question",""))>40 else ""}',
            "action_route": f'/listing/{q["listing_id"]}?tab=qna',
            "created_at": q["question_at"].isoformat() if q.get("question_at") else None,
        })

    return {
        "success": True,
        "data": {
            "todos": todos,
            "total": len(todos),
        },
    }


@app.get("/api/v1/dashboard/recent-events")
def api_dashboard_recent_events(
    current_agent: dict = Depends(get_current_agent),
):
    """工作台 · 过去 24h 内的事件流
    
    事件类型:
    - 我发出的申请被审批(approved / rejected / expired)
    - 我 LA 的房源被申请(新 pending)
    - 我提交的带看被 LA 确认 / 驳回
    - 我的成交被 LA 确认 / 驳回
    - 我的奖金被标记已付
    """
    agent_id = current_agent["_id"]
    now = datetime.now()
    cutoff = now - timedelta(hours=24)
    events = []

    # --- 1. 我发出的申请 · 过去 24h 有状态变化 ---
    my_sent_reviewed = list(db["showing_requests"].find({
        "buyer_agent_id": agent_id,
        "status": {"$in": ["approved", "rejected", "expired"]},
        "reviewed_at": {"$gte": cutoff},
    }).sort("reviewed_at", -1).limit(10))

    for r in my_sent_reviewed:
        status = r.get("status")
        snapshot = r.get("listing_snapshot", {})
        la_name = r.get("listing_agent_name", "同行")
        if status == "approved":
            text = f"{la_name} 通过了你对 {snapshot.get('community','')} 的申请"
            icon = "check_circle"
            color = "green"
        elif status == "rejected":
            text = f"{la_name} 拒绝了你对 {snapshot.get('community','')} 的申请"
            icon = "cancel"
            color = "red"
        else:  # expired
            text = f"对 {snapshot.get('community','')} 的申请已过期(7 天未处理)"
            icon = "timer_off"
            color = "grey"
        events.append({
            "type": "sent_request_reviewed",
            "icon": icon,
            "color": color,
            "text": text,
            "time": r["reviewed_at"].isoformat() if r.get("reviewed_at") else None,
            "route": f"/showing-request/{str(r['_id'])}",
        })

    # --- 2. 我 LA 的房源 · 过去 24h 被申请(新 pending) ---
    my_la_new = list(db["showing_requests"].find({
        "listing_agent_id": agent_id,
        "status": "pending",
        "created_at": {"$gte": cutoff},
    }).sort("created_at", -1).limit(10))

    for r in my_la_new:
        snapshot = r.get("listing_snapshot", {})
        events.append({
            "type": "received_request_new",
            "icon": "person_add",
            "color": "orange",
            "text": f"{r.get('buyer_agent_name','同行')} 申请带看你的 {snapshot.get('community','')}",
            "time": r["created_at"].isoformat() if r.get("created_at") else None,
            "route": f"/showing-request/{str(r['_id'])}",
        })

    # --- 3. 我提交的带看 · 24h 内被 LA 确认或驳回(BA 视角) ---
    my_ba_shows = list(db["showings"].find({
        "ba_agent_id": agent_id,
        "status": {"$in": ["confirmed", "rejected"]},
        "confirmed_at": {"$gte": cutoff},
    }).sort("confirmed_at", -1).limit(10))

    for s in my_ba_shows:
        snapshot = s.get("listing_snapshot", {})
        if s.get("status") == "confirmed":
            text = f"带看记录已确认 · {snapshot.get('community','')}"
            icon = "check_circle"
            color = "green"
        else:
            text = f"带看被驳回 · {snapshot.get('community','')}"
            icon = "cancel"
            color = "red"
        events.append({
            "type": "my_showing_reviewed",
            "icon": icon,
            "color": color,
            "text": text,
            "time": s["confirmed_at"].isoformat() if s.get("confirmed_at") else None,
            "route": f"/showing/{str(s['_id'])}/confirm",
        })

    # 按时间降序排,最多返 15 条
    events.sort(key=lambda e: e.get("time") or "", reverse=True)
    events = events[:15]

    return {
        "success": True,
        "data": {
            "events": events,
            "total": len(events),
        },
    }

@app.get("/api/v1/collaborations/mine")
def api_list_my_collaborations(
    role: str,
    current_agent: dict = Depends(get_current_agent),
):
    """查我的协作列表(协作 = 一条申请 + 关联的带看/成交/结算)
    
    role 参数:
    - buyer: 我作为 BA 的协作
    - seller: 我作为 LA 的协作
    """
    if role not in ("buyer", "seller"):
        raise HTTPException(
            status_code=400, detail="role 必须是 buyer 或 seller"
        )
    items = list_my_collaborations(str(current_agent["_id"]), role)
    return {
        "success": True,
        "data": {"items": items, "total": len(items)},
    }