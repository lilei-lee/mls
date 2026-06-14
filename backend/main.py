"""
MLS 后端 — 应用入口（thin shell, <100 行）
路由拆分后的唯一职责: FastAPI() 创建、include_router、startup/shutdown

路由分区 → 新文件对照:
  ═══ JWT 工具层 + 认证 ═══   backend/auth.py
  ═══ 房源 ═══                backend/routers/listings.py
  ═══ 带客申请 ═══            backend/routers/showing_requests.py
  ═══ 带看记录 ═══            backend/routers/showings.py
  ═══ 成交确认 ═══            backend/routers/transactions.py
  ═══ Dashboard ═══           backend/routers/dashboard.py
  ═══ 小区 ═══                backend/routers/communities.py
  ═══ 奖金结算 ═══            backend/routers/settlements.py
  ═══ 客户管理 ═══            backend/routers/customers.py
  ═══ 协作 ═══                backend/routers/collaborations.py
  ═══ Q&A ═══                 backend/routers/qna.py
  ═══ 照片 ═══                backend/routers/photos.py

业务逻辑:
  backend/services/listings.py (原 backend/listings.py, 1255 行)
  backend/showing_requests.py / showings.py / transactions.py ...
"""
from datetime import datetime
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import config
from membership import is_member_active
from database import ping

from services.listings import ensure_indexes
from showing_requests import ensure_showing_indexes
from showings import ensure_showings_indexes
from communities import ensure_communities_indexes
from transactions import ensure_transactions_indexes
from settlements import ensure_settlements_indexes
from customers import ensure_customers_indexes
from disputes import ensure_disputes_indexes
from ownership import ensure_ownership_indexes
from scheduler import start_scheduler, stop_scheduler
from storage import ensure_bucket

# ── Routers ──
from auth import auth_router
from routers.listings import listings_router
from routers.showing_requests import showing_requests_router
from routers.showings import showings_router
from routers.transactions import transactions_router
from routers.dashboard import dashboard_router
from routers.communities import communities_router
from routers.settlements import settlements_router
from routers.customers import customers_router
from routers.collaborations import collaborations_router
from routers.qna import qna_router
from routers.photos import photos_router
from routers.admin import admin_router
from routers.disputes import disputes_router
from routers.ownership import ownership_router

app = FastAPI(
    title="MLS 后端 API",
    description="张家口MLS经纪人系统 - 后端服务",
    version="0.1.0"
)

# 管理后台:把当前管理员用户名写进 ContextVar(审计日志归属到人)
from admin_auth import ActorContextMiddleware
app.add_middleware(ActorContextMiddleware)


@app.get("/")
def root():
    return {
        "service": "MLS 后端",
        "status": "running",
        "time": datetime.now().isoformat()
    }


@app.middleware("http")
async def membership_guard(request: Request, call_next):
    """会员费机制:开关开启时,过期会员的写操作返 402(全功能只读)。
    放行:GET/HEAD/OPTIONS(看) + /api/v1/auth/*(登录/注册/重置)。
    开关关闭(免费期)时本中间件不拦任何请求。
    """
    if config.MEMBERSHIP_ENFORCED and request.method not in ("GET", "HEAD", "OPTIONS"):
        path = request.url.path
        if not path.startswith("/api/v1/auth/"):
            from auth import get_agent_from_token  # 延迟导入避免环
            authz = request.headers.get("authorization", "")
            if authz.lower().startswith("bearer "):
                agent = get_agent_from_token(authz[7:])
                if agent is not None and not is_member_active(agent):
                    return JSONResponse(
                        status_code=402,
                        content={"detail": "会员已过期,当前为只读模式,请联系续费后继续"},
                    )
    return await call_next(request)

# ── Register all routers ──
app.include_router(auth_router)
app.include_router(listings_router)
app.include_router(showing_requests_router)
app.include_router(showings_router)
app.include_router(transactions_router)
app.include_router(dashboard_router)
app.include_router(communities_router)
app.include_router(settlements_router)
app.include_router(customers_router)
app.include_router(collaborations_router)
app.include_router(qna_router)
app.include_router(photos_router)
app.include_router(admin_router)
app.include_router(disputes_router)
app.include_router(ownership_router)


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
    ensure_disputes_indexes()
    print("[OK] 争议举报索引已建立")
    ensure_ownership_indexes()
    print("[OK] 归属变更索引已建立")
    from admin_users import ensure_admin_indexes, ensure_seed_admin
    ensure_admin_indexes()
    ensure_seed_admin()
    print("[OK] 管理员账号索引/种子已就绪")
    ensure_bucket()
    start_scheduler()


@app.on_event("shutdown")
def shutdown_hook():
    stop_scheduler()
