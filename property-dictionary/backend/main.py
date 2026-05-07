"""Property Dictionary Service — 楼盘辞典独立微服务"""
from fastapi import FastAPI
from config import DICT_PORT, DICT_MONGO_DB, DICT_SECRET_KEY
from database import ping_db
from api.v1.properties import router as properties_router

app = FastAPI(title="Property Dictionary Service", version="0.1.0")
app.include_router(properties_router)


@app.on_event("startup")
def on_startup():
    print(f"[Property Dictionary] starting on port {DICT_PORT}")
    print(f"[Property Dictionary] mongo db: {DICT_MONGO_DB}")
    if DICT_SECRET_KEY == "CHANGE_ME_DEV":
        print("[Property Dictionary] WARNING: using dev SECRET_KEY, 生产前必须替换")


@app.get("/")
def root():
    return {"service": "property-dictionary", "version": "0.1.0"}


@app.get("/health")
def health():
    return {"status": "ok", "mongo": ping_db()}
