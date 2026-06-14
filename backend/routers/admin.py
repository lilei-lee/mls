"""Web 管理后台(模块六)第一片:登录 + 数据看板 + 会员管理。

技术:FastAPI + Jinja2 服务端渲染。管理员会话见 admin_auth.py。
仅运营(磊)使用,经纪人不可访问。后续增量扩:经纪人管理 / 房源审核 / 争议仲裁。
"""
import os
from datetime import datetime, timedelta
from urllib.parse import quote

from bson import ObjectId
from fastapi import APIRouter, Request, Form, Depends, status, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from database import db
from membership import set_membership_by_phone
from admin_auth import COOKIE_NAME, MAX_AGE, make_admin_cookie, check_credentials, require_admin

_TEMPLATES_DIR = os.path.join(os.path.dirname(__file__), "..", "templates")
templates = Jinja2Templates(directory=_TEMPLATES_DIR)

admin_router = APIRouter(prefix="/admin", tags=["admin"])


def _month_start() -> datetime:
    now = datetime.now()
    return datetime(now.year, now.month, 1)


def _dashboard_metrics() -> dict:
    agents, listings, txs = db["agents"], db["listings"], db["transactions"]
    mstart, now = _month_start(), datetime.now()

    agent_by_status = {s: agents.count_documents({"status": s}) for s in ("active", "suspended", "banned")}
    listing_by_status = {s: listings.count_documents({"status": s})
                         for s in ("on_sale", "deposit_paid", "transaction_ongoing", "sold", "offline")}
    confirmed_month = list(txs.find({"status": "confirmed", "confirmed_at": {"$gte": mstart}}))
    deal_amount = sum(int(t.get("ba_deal_price_yuan", 0) or 0) for t in confirmed_month)

    return {
        "agent_total": agents.count_documents({}),
        "agent_by_status": agent_by_status,
        "member_active": agents.count_documents({"membership_expires_at": {"$gt": now}}),
        "listing_total": listings.count_documents({}),
        "listing_by_status": listing_by_status,
        "new_listings_month": listings.count_documents({"created_at": {"$gte": mstart}}),
        "deal_count_month": len(confirmed_month),
        "deal_amount_wan": round(deal_amount / 10000, 1),
    }


# ── 登录 / 登出 ──

@admin_router.get("/login", response_class=HTMLResponse)
def admin_login_page(request: Request, error: str = ""):
    return templates.TemplateResponse(request, "admin/login.html", {"error": error})


@admin_router.post("/login")
def admin_login(request: Request, username: str = Form(...), password: str = Form(...)):
    if not check_credentials(username, password):
        return templates.TemplateResponse(
            request, "admin/login.html", {"error": "账号或密码错误"}, status_code=401)
    resp = RedirectResponse(url="/admin/", status_code=status.HTTP_303_SEE_OTHER)
    resp.set_cookie(COOKIE_NAME, make_admin_cookie(), max_age=MAX_AGE, httponly=True, samesite="lax")
    return resp


@admin_router.get("/logout")
def admin_logout():
    resp = RedirectResponse(url="/admin/login", status_code=status.HTTP_303_SEE_OTHER)
    resp.delete_cookie(COOKIE_NAME)
    return resp


# ── 数据看板 ──

@admin_router.get("/", response_class=HTMLResponse)
def admin_dashboard(request: Request, _: bool = Depends(require_admin)):
    return templates.TemplateResponse(request, "admin/dashboard.html", {"m": _dashboard_metrics()})


# ── 会员管理 ──

@admin_router.get("/members", response_class=HTMLResponse)
def admin_members(request: Request, _: bool = Depends(require_admin), msg: str = ""):
    now = datetime.now()
    rows = []
    cur = db["agents"].find(
        {}, {"name": 1, "phone": 1, "store_name": 1, "status": 1, "membership_expires_at": 1}
    ).sort("created_at", -1)
    for a in cur:
        exp = a.get("membership_expires_at")
        rows.append({
            "name": a.get("name", ""),
            "phone": a.get("phone", ""),
            "store_name": a.get("store_name", ""),
            "status": a.get("status", ""),
            "expires_at": exp.strftime("%Y-%m-%d") if isinstance(exp, datetime) else "-",
            "active": isinstance(exp, datetime) and exp > now,
        })
    return templates.TemplateResponse(request, "admin/members.html", {"rows": rows, "msg": msg})


@admin_router.post("/members/grant")
def admin_grant_member(_: bool = Depends(require_admin), phone: str = Form(...), days: int = Form(...)):
    expires = datetime.now() + timedelta(days=days)
    res = set_membership_by_phone(phone.strip(), expires)
    msg = (f"已为 {res['agent_name']}({phone}) 开通至 {res['expires_at']}"
           if res.get("matched") else f"未找到手机号 {phone}")
    return RedirectResponse(url=f"/admin/members?msg={quote(msg)}", status_code=status.HTTP_303_SEE_OTHER)


# ── 经纪人管理(只读 + 联卖审核) ──

_AGENT_STATUS_LABEL = {"active": "正常", "suspended": "暂停", "banned": "已踢出", "deleted": "已删除"}


@admin_router.get("/agents", response_class=HTMLResponse)
def admin_agents(request: Request, _: bool = Depends(require_admin),
                 q: str = "", status_f: str = "", msg: str = ""):
    now = datetime.now()
    query: dict = {}
    if status_f:
        query["status"] = status_f
    if q:
        query["$or"] = [
            {"name": {"$regex": q, "$options": "i"}},
            {"phone": {"$regex": q}},
            {"store_name": {"$regex": q, "$options": "i"}},
        ]
    rows = []
    for a in db["agents"].find(query).sort("created_at", -1):
        aid = a["_id"]
        exp = a.get("membership_expires_at")
        rows.append({
            "id": str(aid),
            "name": a.get("name", ""),
            "phone": a.get("phone", ""),
            "store_name": a.get("store_name", ""),
            "role": a.get("role", "agent"),
            "status": a.get("status", ""),
            "status_label": _AGENT_STATUS_LABEL.get(a.get("status", ""), a.get("status", "")),
            "coop_verified": bool(a.get("coop_verified")),
            "listing_count": db["listings"].count_documents({"owner_agent_id": aid}),
            "member_active": isinstance(exp, datetime) and exp > now,
        })
    return templates.TemplateResponse(request, "admin/agents.html",
                                      {"rows": rows, "q": q, "status_f": status_f, "msg": msg})


@admin_router.get("/agents/{agent_id}", response_class=HTMLResponse)
def admin_agent_detail(agent_id: str, request: Request, _: bool = Depends(require_admin)):
    now = datetime.now()
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    a = db["agents"].find_one({"_id": aid})
    if not a:
        raise HTTPException(status_code=404, detail="经纪人不存在")
    exp = a.get("membership_expires_at")
    listings = list(db["listings"].find({"owner_agent_id": aid}).sort("created_at", -1).limit(50))
    deal_count = db["transactions"].count_documents({
        "status": "confirmed",
        "$or": [{"la_agent_id": aid}, {"ba_agent_id": aid}],
    })
    agent = {
        "id": str(aid),
        "name": a.get("name", ""),
        "phone": a.get("phone", ""),
        "store_name": a.get("store_name", ""),
        "role": a.get("role", "agent"),
        "status": a.get("status", ""),
        "status_label": _AGENT_STATUS_LABEL.get(a.get("status", ""), a.get("status", "")),
        "coop_verified": bool(a.get("coop_verified")),
        "created_at": a["created_at"].strftime("%Y-%m-%d") if isinstance(a.get("created_at"), datetime) else "-",
        "member_active": isinstance(exp, datetime) and exp > now,
        "expires_at": exp.strftime("%Y-%m-%d") if isinstance(exp, datetime) else "-",
        "deal_count": deal_count,
    }
    listing_rows = [{
        "community": l.get("community", ""),
        "building": l.get("building", ""), "room_no": l.get("room_no", ""),
        "price_wan": l.get("price_wan", ""),
        "status": l.get("status", ""),
    } for l in listings]
    return templates.TemplateResponse(request, "admin/agent_detail.html",
                                      {"a": agent, "listings": listing_rows})


@admin_router.post("/agents/{agent_id}/coop")
def admin_agent_coop(agent_id: str, _: bool = Depends(require_admin), action: str = Form(...)):
    """联卖审核:通过(approve)/拒绝(reject),记录 coop_verified + 审核时间。"""
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    db["agents"].update_one({"_id": aid}, {"$set": {
        "coop_verified": action == "approve",
        "coop_reviewed_at": datetime.now(),
        "updated_at": datetime.now(),
    }})
    return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)


# ── 房源管理(只读 + 手动下架/恢复) ──

_LISTING_STATUS_LABEL = {
    "on_sale": "在售", "deposit_paid": "定金已付", "transaction_ongoing": "成交进行中",
    "sold": "已售", "offline": "已下架",
}


@admin_router.get("/listings", response_class=HTMLResponse)
def admin_listings(request: Request, _: bool = Depends(require_admin),
                   q: str = "", status_f: str = "", district_f: str = "", msg: str = ""):
    query: dict = {}
    if status_f:
        query["status"] = status_f
    if district_f:
        query["district"] = district_f
    if q:
        query["$or"] = [
            {"community": {"$regex": q, "$options": "i"}},
            {"owner_agent_name": {"$regex": q, "$options": "i"}},
            {"house_code": {"$regex": q, "$options": "i"}},
        ]
    rows = []
    for l in db["listings"].find(query).sort("created_at", -1).limit(200):
        rows.append({
            "id": str(l["_id"]),
            "house_code": l.get("house_code", "-"),
            "community": l.get("community", ""),
            "building": l.get("building", ""), "room_no": l.get("room_no", ""),
            "district": l.get("district", ""),
            "price_wan": l.get("price_wan", ""),
            "status": l.get("status", ""),
            "status_label": _LISTING_STATUS_LABEL.get(l.get("status", ""), l.get("status", "")),
            "owner": l.get("owner_agent_name", ""),
        })
    districts = [d for d in db["listings"].distinct("district") if d]
    return templates.TemplateResponse(request, "admin/listings.html", {
        "rows": rows, "q": q, "status_f": status_f, "district_f": district_f,
        "districts": districts, "msg": msg,
    })


@admin_router.get("/listings/{listing_id}", response_class=HTMLResponse)
def admin_listing_detail(listing_id: str, request: Request, _: bool = Depends(require_admin), msg: str = ""):
    try:
        lid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源 ID")
    l = db["listings"].find_one({"_id": lid})
    if not l:
        raise HTTPException(status_code=404, detail="房源不存在")
    listing = {
        "id": str(lid),
        "house_code": l.get("house_code", "-"),
        "community": l.get("community", ""),
        "building": l.get("building", ""), "unit": l.get("unit", ""), "room_no": l.get("room_no", ""),
        "district": l.get("district", ""),
        "price_wan": l.get("price_wan", ""),
        "bonus_yuan": l.get("bonus_yuan", 0),
        "status": l.get("status", ""),
        "status_label": _LISTING_STATUS_LABEL.get(l.get("status", ""), l.get("status", "")),
        "owner": l.get("owner_agent_name", ""),
        "owner_phone": l.get("owner_agent_phone", ""),
        "photo_count": l.get("photo_count", len(l.get("photos", []) or [])),
        "property_code": l.get("property_code", "-"),
        "public_remarks": l.get("public_remarks", ""),
        "created_at": l["created_at"].strftime("%Y-%m-%d") if isinstance(l.get("created_at"), datetime) else "-",
        "can_offline": l.get("status") == "on_sale",
        "can_restore": l.get("status") == "offline",
    }
    return templates.TemplateResponse(request, "admin/listing_detail.html", {"l": listing, "msg": msg})


def _set_listing_status(listing_id: str, allowed_from: str, new_status: str, reason: str) -> str:
    try:
        lid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源 ID")
    l = db["listings"].find_one({"_id": lid})
    if not l:
        raise HTTPException(status_code=404, detail="房源不存在")
    if l.get("status") != allowed_from:
        return f"当前状态({_LISTING_STATUS_LABEL.get(l.get('status'), l.get('status'))})不可执行该操作"
    upd = {"status": new_status, "updated_at": datetime.now()}
    if new_status == "offline":
        upd["offline_reason"] = reason
    db["listings"].update_one({"_id": lid}, {"$set": upd})
    return "已下架" if new_status == "offline" else "已恢复上架"


@admin_router.post("/listings/{listing_id}/offline")
def admin_listing_offline(listing_id: str, _: bool = Depends(require_admin), reason: str = Form("")):
    msg = _set_listing_status(listing_id, "on_sale", "offline", reason.strip())
    return RedirectResponse(url=f"/admin/listings/{listing_id}?msg={quote(msg)}",
                            status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/listings/{listing_id}/restore")
def admin_listing_restore(listing_id: str, _: bool = Depends(require_admin)):
    msg = _set_listing_status(listing_id, "offline", "on_sale", "")
    return RedirectResponse(url=f"/admin/listings/{listing_id}?msg={quote(msg)}",
                            status_code=status.HTTP_303_SEE_OTHER)
