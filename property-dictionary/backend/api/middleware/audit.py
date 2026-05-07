"""audit_log 中间件 — 写操作自动留痕"""
import time, json, re
from datetime import datetime
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import Message

from models.audit_log import audit_logs_collection
from config import DICT_API_KEYS

SKIP_PATHS = {"/", "/health", "/docs", "/openapi.json", "/redoc"}
BODY_SUMMARY_MAX = 200


def _summarize_body(body_bytes: bytes) -> str:
    if not body_bytes:
        return ""
    try:
        text = body_bytes.decode("utf-8", errors="replace")
    except Exception:
        return f"<binary {len(body_bytes)} bytes>"
    text = re.sub(r'("(?:password|secret|token|api_key)"\s*:\s*)"[^"]*"', r'\1"***"', text, flags=re.IGNORECASE)
    if len(text) > BODY_SUMMARY_MAX:
        return text[:BODY_SUMMARY_MAX] + "...(truncated)"
    return text


def _extract_api_key_meta(request: Request) -> dict:
    key = request.headers.get("x-api-key", "")
    if not key:
        return {"api_key_owner": None, "api_key_prefix": None}
    meta = DICT_API_KEYS.get(key)
    if not meta:
        return {"api_key_owner": "unknown", "api_key_prefix": key[:8] + "..." if len(key) > 8 else key}
    return {"api_key_owner": meta["owner"], "api_key_prefix": key[:8] + "..." if len(key) > 8 else key}


def _extract_city_id(path: str, query: str, body_text: str) -> str | None:
    if "city_id=" in query:
        try:
            for part in query.split("&"):
                if part.startswith("city_id="):
                    return part.split("=", 1)[1]
        except Exception:
            pass
    if body_text:
        try:
            obj = json.loads(body_text)
            if isinstance(obj, dict) and "city_id" in obj:
                return str(obj["city_id"])
        except Exception:
            pass
    return None


class AuditLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in SKIP_PATHS:
            return await call_next(request)

        is_write = request.method in ("POST", "PATCH", "PUT", "DELETE")
        is_v1 = request.url.path.startswith("/v1/")
        if not is_write:
            return await call_next(request)

        body_bytes = await request.body()

        async def receive() -> Message:
            return {"type": "http.request", "body": body_bytes, "more_body": False}
        request._receive = receive

        start = time.time()
        response = await call_next(request)
        latency_ms = int((time.time() - start) * 1000)

        body_summary = _summarize_body(body_bytes)
        key_meta = _extract_api_key_meta(request)
        city_id = _extract_city_id(request.url.path, request.url.query or "", body_summary)

        try:
            audit_logs_collection.insert_one({
                "method": request.method, "path": request.url.path,
                "query": request.url.query or None,
                "city_id": city_id,
                "api_key_owner": key_meta["api_key_owner"],
                "api_key_prefix": key_meta["api_key_prefix"],
                "status_code": response.status_code,
                "request_body_summary": body_summary,
                "ip": request.client.host if request.client else None,
                "user_agent": request.headers.get("user-agent", ""),
                "latency_ms": latency_ms, "created_at": datetime.now(),
            })
        except Exception as e:
            print(f"[audit] WARNING: failed to write audit log: {e}")

        return response
