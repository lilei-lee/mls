"""Property Dictionary Service — 楼盘辞典独立微服务"""
from fastapi import FastAPI
from config import DICT_PORT, DICT_MONGO_DB, DICT_SECRET_KEY
from database import ping_db
from api.v1.properties import router as properties_router
from api.v1.discrepancies import router as discrepancies_router

from api.middleware.audit import AuditLogMiddleware
from models.audit_log import ensure_audit_log_indexes

app = FastAPI(title="Property Dictionary Service", version="0.1.0")
app.add_middleware(AuditLogMiddleware)
app.include_router(properties_router)
app.include_router(discrepancies_router)


@app.on_event("startup")
def on_startup():
    print(f"[Property Dictionary] starting on port {DICT_PORT}")
    print(f"[Property Dictionary] mongo db: {DICT_MONGO_DB}")
    if DICT_SECRET_KEY == "CHANGE_ME_DEV":
        print("[Property Dictionary] WARNING: using dev SECRET_KEY, 生产前必须替换")

    from config import DICT_API_KEYS
    if not DICT_API_KEYS:
        print("[Property Dictionary] WARNING: NO API KEYS LOADED — all /v1/* requests will return 401/403")
    else:
        print(f"[Property Dictionary] {len(DICT_API_KEYS)} API key(s) loaded:")
        for key_str, meta in DICT_API_KEYS.items():
            prefix = key_str[:8] + "..." if len(key_str) > 8 else key_str
            print(f"  - {prefix} owner={meta['owner']} scope={meta['city_scope']} active={meta['active']}")

    audit_idx = ensure_audit_log_indexes()
    print(f"[Property Dictionary] audit_logs indexes: {len(audit_idx)} total")


@app.get("/")
def root():
    return {"service": "property-dictionary", "version": "0.1.0"}


@app.get("/health")
def health():
    return {"status": "ok", "mongo": ping_db()}
