"""Web 管理后台(模块六)第一片:登录 + 数据看板 + 会员管理。

技术:FastAPI + Jinja2 服务端渲染。管理员会话见 admin_auth.py。
仅运营(磊)使用,经纪人不可访问。后续增量扩:经纪人管理 / 房源审核 / 争议仲裁。
"""
import csv
import io
import os
from datetime import datetime, timedelta
from urllib.parse import quote

from bson import ObjectId
from fastapi import APIRouter, Request, Form, Depends, status, HTTPException, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates

from database import db
from audit import write_audit, ACTION_LABEL
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


def _month_ranges():
    """返回 (上月起, 本月起, 现在)。"""
    now = datetime.now()
    this_start = datetime(now.year, now.month, 1)
    last_start = (datetime(now.year - 1, 12, 1) if now.month == 1
                  else datetime(now.year, now.month - 1, 1))
    return last_start, this_start, now


def _delta_pct(cur: int, prev: int):
    """环比百分比;上月为 0 时返回 None(无基数)。"""
    if prev == 0:
        return None
    return round((cur - prev) / prev * 100, 1)


def _dashboard_extra() -> dict:
    agents, listings, txs, srs = db["agents"], db["listings"], db["transactions"], db["showing_requests"]
    last_start, this_start, now = _month_ranges()

    def _cnt(coll, field, lo, hi):
        return coll.count_documents({field: {"$gte": lo, "$lt": hi}})

    def _deal_cnt(lo, hi):
        return txs.count_documents({"status": "confirmed", "confirmed_at": {"$gte": lo, "$lt": hi}})

    mom = []
    for label, cur, prev in [
        ("新增房源", _cnt(listings, "created_at", this_start, now), _cnt(listings, "created_at", last_start, this_start)),
        ("成交量", _deal_cnt(this_start, now), _deal_cnt(last_start, this_start)),
        ("带客申请", _cnt(srs, "created_at", this_start, now), _cnt(srs, "created_at", last_start, this_start)),
    ]:
        mom.append({"label": label, "cur": cur, "prev": prev, "pct": _delta_pct(cur, prev)})

    regions = []
    for d in [x for x in listings.distinct("district") if x]:
        prices = [l["price_wan"] for l in listings.find({"district": d}, {"price_wan": 1})
                  if isinstance(l.get("price_wan"), (int, float))]
        regions.append({
            "district": d,
            "count": listings.count_documents({"district": d}),
            "sold": listings.count_documents({"district": d, "status": "sold"}),
            "avg_price": round(sum(prices) / len(prices), 1) if prices else 0,
        })
    regions.sort(key=lambda r: r["count"], reverse=True)

    stores = []
    for s in agents.distinct("store_name"):
        ids = [a["_id"] for a in agents.find({"store_name": s}, {"_id": 1})]
        if not ids:
            continue
        stores.append({
            "store": s or "(未填)",
            "agents": len(ids),
            "listings": listings.count_documents({"owner_agent_id": {"$in": ids}}),
            "deals": txs.count_documents({
                "status": "confirmed", "confirmed_at": {"$gte": this_start},
                "$or": [{"la_agent_id": {"$in": ids}}, {"ba_agent_id": {"$in": ids}}],
            }),
        })
    stores.sort(key=lambda r: r["listings"], reverse=True)

    return {"mom": mom, "regions": regions, "stores": stores}


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
    return templates.TemplateResponse(request, "admin/dashboard.html",
                                      {"m": _dashboard_metrics(), "x": _dashboard_extra()})


# ── 会员开通/续期(挂在经纪人详情页) ──

@admin_router.post("/agents/{agent_id}/membership")
def admin_agent_membership(agent_id: str, _: bool = Depends(require_admin), days: int = Form(...)):
    """给指定经纪人开通/续期会员(从其详情页操作)。"""
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    if not db["agents"].find_one({"_id": aid}):
        raise HTTPException(status_code=404, detail="经纪人不存在")
    db["agents"].update_one({"_id": aid}, {"$set": {
        "membership_expires_at": datetime.now() + timedelta(days=days),
        "updated_at": datetime.now(),
    }})
    write_audit("membership_grant", "agent", agent_id, {"days": days})
    return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)


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
        "can_ban": a.get("status") != "banned",
        "can_unban": a.get("status") == "banned",
        "can_suspend": a.get("status") == "active",
        "can_unsuspend": a.get("status") == "suspended",
        "status_reason": a.get("status_reason", ""),
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
    write_audit("coop_review", "agent", agent_id, {"verified": action == "approve"})
    return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/agents/{agent_id}/ban")
def admin_agent_ban(agent_id: str, _: bool = Depends(require_admin), reason: str = Form("")):
    """踢出经纪人(status=banned,拦登录)。需填原因,记入审计。"""
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    a = db["agents"].find_one({"_id": aid})
    if not a:
        raise HTTPException(status_code=404, detail="经纪人不存在")
    if a.get("status") == "banned":
        return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)
    db["agents"].update_one({"_id": aid}, {"$set": {
        "status": "banned", "status_reason": reason.strip(),
        "status_changed_at": datetime.now(), "updated_at": datetime.now(),
    }})
    write_audit("agent_ban", "agent", agent_id, {"reason": reason.strip()})
    return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/agents/{agent_id}/unban")
def admin_agent_unban(agent_id: str, _: bool = Depends(require_admin)):
    """恢复被踢出的经纪人(status=active)。"""
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    a = db["agents"].find_one({"_id": aid})
    if not a:
        raise HTTPException(status_code=404, detail="经纪人不存在")
    if a.get("status") != "banned":
        return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)
    db["agents"].update_one({"_id": aid}, {"$set": {
        "status": "active", "status_changed_at": datetime.now(), "updated_at": datetime.now(),
    }})
    write_audit("agent_restore", "agent", agent_id, {})
    return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/agents/{agent_id}/suspend")
def admin_agent_suspend(agent_id: str, _: bool = Depends(require_admin), reason: str = Form("")):
    """暂停经纪人(status=suspended):仍可登录/读/完成在途协作,但不能发起新业务。仅暂停 active。"""
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    a = db["agents"].find_one({"_id": aid})
    if not a:
        raise HTTPException(status_code=404, detail="经纪人不存在")
    if a.get("status") != "active":
        return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)
    db["agents"].update_one({"_id": aid}, {"$set": {
        "status": "suspended", "status_reason": reason.strip(),
        "status_changed_at": datetime.now(), "updated_at": datetime.now(),
    }})
    write_audit("agent_suspend", "agent", agent_id, {"reason": reason.strip()})
    return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/agents/{agent_id}/unsuspend")
def admin_agent_unsuspend(agent_id: str, _: bool = Depends(require_admin)):
    """解除暂停(status=active)。仅对 suspended 生效。"""
    try:
        aid = ObjectId(agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的经纪人 ID")
    a = db["agents"].find_one({"_id": aid})
    if not a:
        raise HTTPException(status_code=404, detail="经纪人不存在")
    if a.get("status") != "suspended":
        return RedirectResponse(url=f"/admin/agents/{agent_id}", status_code=status.HTTP_303_SEE_OTHER)
    db["agents"].update_one({"_id": aid}, {"$set": {
        "status": "active", "status_changed_at": datetime.now(), "updated_at": datetime.now(),
    }})
    write_audit("agent_unsuspend", "agent", agent_id, {})
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
        "ownership_locked": bool(l.get("ownership_locked")),
        "can_transfer": l.get("status") != "sold" and not l.get("ownership_locked"),
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
    write_audit("listing_offline" if new_status == "offline" else "listing_restore",
                "listing", listing_id, {"reason": reason} if reason else {})
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


# ── 审计日志查看 ──

@admin_router.get("/audit", response_class=HTMLResponse)
def admin_audit(request: Request, _: bool = Depends(require_admin), action_f: str = ""):
    query: dict = {}
    if action_f:
        query["action"] = action_f
    rows = []
    for e in db["audit_log"].find(query).sort("created_at", -1).limit(300):
        rows.append({
            "action": e.get("action", ""),
            "action_label": ACTION_LABEL.get(e.get("action", ""), e.get("action", "")),
            "actor": e.get("actor", ""),
            "target_type": e.get("target_type", ""),
            "target_id": e.get("target_id", ""),
            "detail": e.get("detail", {}),
            "created_at": e["created_at"].strftime("%Y-%m-%d %H:%M:%S") if isinstance(e.get("created_at"), datetime) else "-",
        })
    return templates.TemplateResponse(request, "admin/audit.html",
                                      {"rows": rows, "action_f": action_f, "action_labels": ACTION_LABEL})


# ── 小区库管理(列表 + 编辑) ──

@admin_router.get("/communities", response_class=HTMLResponse)
def admin_communities(request: Request, _: bool = Depends(require_admin), q: str = "", msg: str = ""):
    query: dict = {}
    if q:
        query["$or"] = [
            {"name": {"$regex": q, "$options": "i"}},
            {"district": {"$regex": q, "$options": "i"}},
            {"filing_name": {"$regex": q, "$options": "i"}},
            {"aliases": {"$regex": q, "$options": "i"}},
        ]
    rows = []
    for c in db["communities"].find(query).sort("name", 1).limit(300):
        _alt = [c.get("filing_name")] + (c.get("aliases") or [])
        rows.append({
            "id": str(c["_id"]),
            "name": c.get("name", ""),
            "district": c.get("district", ""),
            "alt_names": "、".join([x for x in _alt if x]) or "-",
            "built_year": c.get("built_year") or "-",
            "building_count": c.get("building_count") or "-",
            "listing_count": db["listings"].count_documents({
                "community": c.get("name", ""), "district": c.get("district", "")}),
        })
    return templates.TemplateResponse(request, "admin/communities.html", {"rows": rows, "q": q, "msg": msg})


@admin_router.get("/communities/{community_id}", response_class=HTMLResponse)
def admin_community_edit(community_id: str, request: Request, _: bool = Depends(require_admin), msg: str = ""):
    from communities import COMMUNITY_RICH_FIELDS
    try:
        cid = ObjectId(community_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的小区 ID")
    c = db["communities"].find_one({"_id": cid})
    if not c:
        raise HTTPException(status_code=404, detail="小区不存在")
    community = {
        "id": str(cid),
        "name": c.get("name", ""),
        "district": c.get("district", ""),
        "filing_name": c.get("filing_name") or "",
        "aliases": "、".join(c.get("aliases") or []),
        "built_year": c.get("built_year") or "",
        "building_count": c.get("building_count") or "",
        "listing_count": db["listings"].count_documents({
            "community": c.get("name", ""), "district": c.get("district", "")}),
    }
    rich = [{"key": f["key"], "label": f["label"], "value": c.get(f["key"]) if c.get(f["key"]) is not None else ""}
            for f in COMMUNITY_RICH_FIELDS]
    return templates.TemplateResponse(request, "admin/community_edit.html",
                                      {"c": community, "rich": rich, "msg": msg})


def _coerce_field(value: str, type_: str):
    v = (value or "").strip()
    if v == "":
        return None
    if type_ == "int":
        try:
            return int(v)
        except ValueError:
            return None
    if type_ == "float":
        try:
            return float(v)
        except ValueError:
            return None
    return v


def _parse_aliases(value: str) -> list:
    """把别名输入(顿号/逗号/分号分隔)拆成去重列表。"""
    import re as _re
    if not value:
        return []
    out = []
    for p in _re.split(r"[、,，;；\n]", value):
        p = p.strip()
        if p and p not in out:
            out.append(p)
    return out


@admin_router.post("/communities/{community_id}")
async def admin_community_save(community_id: str, request: Request, _: bool = Depends(require_admin)):
    from communities import COMMUNITY_RICH_FIELDS
    try:
        cid = ObjectId(community_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的小区 ID")
    form = await request.form()
    name = (form.get("name") or "").strip()
    district = (form.get("district") or "").strip()
    if not name or not district:
        raise HTTPException(status_code=400, detail="小区名 / 区域必填")
    # (name, district) 全局唯一:撞到别的小区则拒绝
    dup = db["communities"].find_one({"name": name, "district": district, "_id": {"$ne": cid}})
    if dup:
        msg = quote(f"「{name}」在{district}已存在,改名失败")
        return RedirectResponse(url=f"/admin/communities/{community_id}?msg={msg}",
                                status_code=status.HTTP_303_SEE_OTHER)
    upd = {"name": name, "district": district, "updated_at": datetime.now()}
    upd["filing_name"] = (form.get("filing_name") or "").strip() or None
    upd["aliases"] = _parse_aliases(form.get("aliases"))
    upd["built_year"] = _coerce_field(form.get("built_year"), "int")
    upd["building_count"] = _coerce_field(form.get("building_count"), "int")
    for f in COMMUNITY_RICH_FIELDS:
        upd[f["key"]] = _coerce_field(form.get(f["key"]), f["type"])
    db["communities"].update_one({"_id": cid}, {"$set": upd})
    write_audit("community_edit", "community", community_id, {"name": name, "district": district})
    return RedirectResponse(url=f"/admin/communities/{community_id}?msg={quote('已保存')}",
                            status_code=status.HTTP_303_SEE_OTHER)


# ── 数据导出(CSV,UTF-8 BOM 兼容 Excel) ──

def _csv_response(filename: str, header: list, rows: list) -> Response:
    buf = io.StringIO()
    buf.write("﻿")  # BOM,Excel 正确识别 UTF-8 中文
    w = csv.writer(buf)
    w.writerow(header)
    w.writerows(rows)
    return Response(content=buf.getvalue(), media_type="text/csv; charset=utf-8",
                    headers={"Content-Disposition": f'attachment; filename="{filename}"'})


def _fmt_date(v) -> str:
    return v.strftime("%Y-%m-%d") if isinstance(v, datetime) else ""


@admin_router.get("/export/agents.csv")
def export_agents(_: bool = Depends(require_admin)):
    rows = []
    for a in db["agents"].find().sort("created_at", -1):
        rows.append([
            a.get("name", ""), a.get("phone", ""), a.get("store_name", ""),
            "门店老板" if a.get("role") == "boss" else "经纪人",
            a.get("status", ""), "是" if a.get("coop_verified") else "否",
            _fmt_date(a.get("membership_expires_at")), _fmt_date(a.get("created_at")),
        ])
    write_audit("export", "agents", "-", {"count": len(rows)})
    return _csv_response("agents.csv",
                         ["姓名", "手机号", "门店", "类型", "状态", "联卖审核", "会员到期", "注册时间"], rows)


# 房源导出字段集(表头 + 取值,两处共用,保证模板与数据列一致)
_LISTING_EXPORT_HEADER = [
    "MLS编号", "小区", "楼栋", "单元", "房号", "区域", "户型", "朝向",
    "挂牌价(万)", "合作奖金(元)", "状态", "产权号", "归属经纪人", "归属手机",
    "公开备注", "录入时间",
]


def _listing_export_row(l: dict) -> list:
    return [
        l.get("house_code", ""), l.get("community", ""), l.get("building", ""),
        l.get("unit", ""), l.get("room_no", ""), l.get("district", ""),
        l.get("layout", ""), l.get("orientation", ""),
        l.get("price_wan", ""), l.get("bonus_yuan", 0),
        _LISTING_STATUS_LABEL.get(l.get("status", ""), l.get("status", "")),
        l.get("property_code", ""), l.get("owner_agent_name", ""),
        l.get("owner_agent_phone", ""), l.get("public_remarks", ""),
        _fmt_date(l.get("created_at")),
    ]


@admin_router.get("/export/listings.csv")
def export_listings(_: bool = Depends(require_admin), empty: int = 0):
    """空白模板导出:只给表头(无数据行)。不再一键全量,要导数据请在列表勾选后走 POST。"""
    write_audit("export", "listings", "-", {"mode": "template"})
    return _csv_response("listings_template.csv", _LISTING_EXPORT_HEADER, [])


@admin_router.post("/export/listings.csv")
async def export_listings_selected(request: Request, _: bool = Depends(require_admin)):
    """选择性导出:只导出列表里勾选的房源(表单字段 ids),一个都没勾 → 只给表头。"""
    form = await request.form()
    oids = []
    for i in form.getlist("ids"):
        try:
            oids.append(ObjectId(i))
        except Exception:
            continue
    rows = []
    if oids:
        for l in db["listings"].find({"_id": {"$in": oids}}).sort("created_at", -1):
            rows.append(_listing_export_row(l))
    write_audit("export", "listings", "-", {"mode": "selected", "count": len(rows)})
    return _csv_response("listings.csv", _LISTING_EXPORT_HEADER, rows)


@admin_router.get("/export/transactions.csv")
def export_transactions(_: bool = Depends(require_admin)):
    rows = []
    for t in db["transactions"].find({"status": "confirmed"}).sort("confirmed_at", -1):
        snap = t.get("listing_snapshot", {})
        rows.append([
            snap.get("community", ""), t.get("ba_agent_name", ""), t.get("la_agent_name", ""),
            t.get("ba_deal_price_yuan", ""), t.get("bonus_yuan_snapshot", ""),
            _fmt_date(t.get("confirmed_at")),
        ])
    write_audit("export", "transactions", "-", {"count": len(rows)})
    return _csv_response("transactions.csv",
                         ["小区", "BA", "LA", "成交价(元)", "合作奖金(元)", "成交确认时间"], rows)


# ── 系统配置 ──

@admin_router.get("/config", response_class=HTMLResponse)
def admin_config(request: Request, _: bool = Depends(require_admin), msg: str = ""):
    from system_config import CONFIG_SPEC, get_config
    rows = [{
        "key": c["key"], "label": c["label"], "note": c["note"],
        "value": get_config(c["key"], c["default"]),
    } for c in CONFIG_SPEC]
    return templates.TemplateResponse(request, "admin/config.html", {"rows": rows, "msg": msg})


@admin_router.post("/config")
async def admin_config_save(request: Request, _: bool = Depends(require_admin)):
    from system_config import CONFIG_SPEC, get_config, set_config
    form = await request.form()
    changed = {}
    for c in CONFIG_SPEC:
        raw = form.get(c["key"])
        if raw is None:
            continue
        try:
            val = int(raw)
        except (TypeError, ValueError):
            continue
        if val < 1:
            continue
        if get_config(c["key"], c["default"]) != val:
            set_config(c["key"], val)
            changed[c["key"]] = val
    if changed:
        write_audit("config_update", "system", "-", changed)
    return RedirectResponse(url=f"/admin/config?msg={quote('已保存')}", status_code=status.HTTP_303_SEE_OTHER)


# ── 小区合并(A 并入 B:房源迁移 + 旧名存别名 + 删 A) ──

def _merge_match(A: dict, aid: ObjectId) -> dict:
    """匹配归属 A 的房源:community_id(ObjectId) 或 (community 名 + district)。"""
    return {"$or": [
        {"community_id": aid},
        {"community": A.get("name", ""), "district": A.get("district", "")},
    ]}


@admin_router.get("/communities/{community_id}/merge", response_class=HTMLResponse)
def admin_community_merge_page(community_id: str, request: Request,
                               _: bool = Depends(require_admin), target: str = ""):
    try:
        aid = ObjectId(community_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的小区 ID")
    A = db["communities"].find_one({"_id": aid})
    if not A:
        raise HTTPException(status_code=404, detail="小区不存在")
    others = [{"id": str(c["_id"]), "name": c["name"], "district": c.get("district", "")}
              for c in db["communities"].find({"_id": {"$ne": aid}}).sort("name", 1)]
    preview = None
    if target:
        try:
            B = db["communities"].find_one({"_id": ObjectId(target)})
        except Exception:
            B = None
        if B:
            preview = {
                "target_id": str(B["_id"]), "target_name": B["name"],
                "target_district": B.get("district", ""),
                "affected": db["listings"].count_documents(_merge_match(A, aid)),
            }
    a = {"id": str(aid), "name": A["name"], "district": A.get("district", "")}
    return templates.TemplateResponse(request, "admin/community_merge.html",
                                      {"a": a, "others": others, "preview": preview})


@admin_router.post("/communities/{community_id}/merge")
def admin_community_merge(community_id: str, _: bool = Depends(require_admin), target: str = Form(...)):
    try:
        aid, bid = ObjectId(community_id), ObjectId(target)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的小区 ID")
    if aid == bid:
        raise HTTPException(status_code=400, detail="不能合并到自己")
    A = db["communities"].find_one({"_id": aid})
    B = db["communities"].find_one({"_id": bid})
    if not A or not B:
        raise HTTPException(status_code=404, detail="小区不存在")
    res = db["listings"].update_many(_merge_match(A, aid), {"$set": {
        "community": B["name"], "community_id": bid, "district": B.get("district", ""),
        "updated_at": datetime.now(),
    }})
    db["communities"].update_one({"_id": bid}, {"$addToSet": {"aliases": A["name"]}})
    db["communities"].delete_one({"_id": aid})
    write_audit("community_merge", "community", community_id,
                {"into": str(bid), "into_name": B["name"], "affected": res.modified_count})
    msg = quote(f"已将「{A['name']}」并入「{B['name']}」,迁移 {res.modified_count} 套房源")
    return RedirectResponse(url=f"/admin/communities?msg={msg}", status_code=status.HTTP_303_SEE_OTHER)


# ── 争议仲裁(模块六 §7) ──

@admin_router.get("/disputes", response_class=HTMLResponse)
def admin_disputes(request: Request, _: bool = Depends(require_admin), status_f: str = ""):
    from disputes import DISPUTE_STATUS_LABEL
    query: dict = {}
    if status_f:
        query["status"] = status_f
    rows = []
    for d in db["disputes"].find(query).sort("created_at", -1).limit(300):
        rows.append({
            "id": str(d["_id"]),
            "reporter": d.get("reporter_name", ""),
            "target_type": d.get("target_type", ""),
            "reason": d.get("reason", ""),
            "status": d.get("status", ""),
            "status_label": DISPUTE_STATUS_LABEL.get(d.get("status", ""), d.get("status", "")),
            "created_at": d["created_at"].strftime("%Y-%m-%d %H:%M") if isinstance(d.get("created_at"), datetime) else "-",
        })
    return templates.TemplateResponse(request, "admin/disputes.html",
                                      {"rows": rows, "status_f": status_f,
                                       "status_labels": DISPUTE_STATUS_LABEL})


@admin_router.get("/disputes/{dispute_id}", response_class=HTMLResponse)
def admin_dispute_detail(dispute_id: str, request: Request, _: bool = Depends(require_admin)):
    from disputes import DISPUTE_STATUS_LABEL, PENALTY_LABEL
    try:
        did = ObjectId(dispute_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的争议 ID")
    d = db["disputes"].find_one({"_id": did})
    if not d:
        raise HTTPException(status_code=404, detail="争议不存在")
    # 关联留痕:目标是成交则取成交记录摘要
    related = None
    if d.get("target_type") == "transaction":
        try:
            t = db["transactions"].find_one({"_id": ObjectId(d["target_id"])})
        except Exception:
            t = None
        if t:
            snap = t.get("listing_snapshot", {})
            related = {
                "kind": "transaction", "community": snap.get("community", ""),
                "ba": t.get("ba_agent_name", ""), "la": t.get("la_agent_name", ""),
                "status": t.get("status", ""),
                "price": t.get("ba_deal_price_yuan", ""),
            }
    elif d.get("target_type") == "agent":
        try:
            ta = db["agents"].find_one({"_id": ObjectId(d["target_id"])})
        except Exception:
            ta = None
        if ta:
            related = {"kind": "agent", "name": ta.get("name", ""),
                       "phone": ta.get("phone", ""), "status": ta.get("status", "")}
    dispute = {
        "id": str(did),
        "reporter": d.get("reporter_name", ""),
        "target_type": d.get("target_type", ""),
        "target_id": d.get("target_id", ""),
        "reason": d.get("reason", ""),
        "description": d.get("description", ""),
        "status": d.get("status", ""),
        "status_label": DISPUTE_STATUS_LABEL.get(d.get("status", ""), d.get("status", "")),
        "ruling": d.get("ruling") or "",
        "penalty": PENALTY_LABEL.get(d.get("penalty"), d.get("penalty") or "-"),
        "created_at": d["created_at"].strftime("%Y-%m-%d %H:%M") if isinstance(d.get("created_at"), datetime) else "-",
        "can_accept": d.get("status") == "pending",
        "can_close": d.get("status") in ("pending", "accepted"),
    }
    return templates.TemplateResponse(request, "admin/dispute_detail.html",
                                      {"d": dispute, "related": related})


def _get_dispute(dispute_id: str) -> tuple:
    try:
        did = ObjectId(dispute_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的争议 ID")
    d = db["disputes"].find_one({"_id": did})
    if not d:
        raise HTTPException(status_code=404, detail="争议不存在")
    return did, d


@admin_router.post("/disputes/{dispute_id}/accept")
def admin_dispute_accept(dispute_id: str, _: bool = Depends(require_admin)):
    did, d = _get_dispute(dispute_id)
    if d.get("status") == "pending":
        db["disputes"].update_one({"_id": did}, {"$set": {"status": "accepted", "updated_at": datetime.now()}})
        write_audit("dispute_accept", "dispute", dispute_id, {})
    return RedirectResponse(url=f"/admin/disputes/{dispute_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/disputes/{dispute_id}/rule")
def admin_dispute_rule(dispute_id: str, _: bool = Depends(require_admin),
                       ruling: str = Form(...), penalty: str = Form("none")):
    """出具裁决:记录事实/处罚;penalty=ban 时联动踢出目标经纪人。"""
    did, d = _get_dispute(dispute_id)
    if d.get("status") in ("resolved", "rejected"):
        return RedirectResponse(url=f"/admin/disputes/{dispute_id}", status_code=status.HTTP_303_SEE_OTHER)
    penalty = penalty if penalty in ("none", "warn", "ban") else "none"
    db["disputes"].update_one({"_id": did}, {"$set": {
        "status": "resolved", "ruling": ruling.strip(), "penalty": penalty,
        "handled_at": datetime.now(), "updated_at": datetime.now(),
    }})
    # 处罚执行:ban 且目标是经纪人 → 踢出
    if penalty == "ban" and d.get("target_type") == "agent":
        try:
            tid = ObjectId(d["target_id"])
            if db["agents"].find_one({"_id": tid}):
                db["agents"].update_one({"_id": tid}, {"$set": {
                    "status": "banned", "status_reason": f"争议裁决:{ruling.strip()[:50]}",
                    "status_changed_at": datetime.now(), "updated_at": datetime.now()}})
                write_audit("agent_ban", "agent", d["target_id"], {"via_dispute": dispute_id})
        except Exception:
            pass
    write_audit("dispute_resolve", "dispute", dispute_id, {"penalty": penalty})
    return RedirectResponse(url=f"/admin/disputes/{dispute_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/disputes/{dispute_id}/reject")
def admin_dispute_reject(dispute_id: str, _: bool = Depends(require_admin), ruling: str = Form(...)):
    did, d = _get_dispute(dispute_id)
    if d.get("status") in ("resolved", "rejected"):
        return RedirectResponse(url=f"/admin/disputes/{dispute_id}", status_code=status.HTTP_303_SEE_OTHER)
    db["disputes"].update_one({"_id": did}, {"$set": {
        "status": "rejected", "ruling": ruling.strip(),
        "handled_at": datetime.now(), "updated_at": datetime.now(),
    }})
    write_audit("dispute_reject", "dispute", dispute_id, {})
    return RedirectResponse(url=f"/admin/disputes/{dispute_id}", status_code=status.HTTP_303_SEE_OTHER)


# ── 定金异常审查(模块六 §5.3,只读监控) ──

@admin_router.get("/deposit-watch", response_class=HTMLResponse)
def admin_deposit_watch(request: Request, _: bool = Depends(require_admin)):
    from system_config import get_config
    window = get_config("deposit_watch_days", 30)
    cutoff = datetime.now() - timedelta(days=window)
    rows = []
    for l in db["listings"].find({"deposit_events.0": {"$exists": True}}):
        events = [e for e in l.get("deposit_events", [])
                  if isinstance(e.get("at"), datetime) and e["at"] >= cutoff]
        if not events:
            continue
        rows.append({
            "id": str(l["_id"]),
            "community": l.get("community", ""),
            "building": l.get("building", ""), "room_no": l.get("room_no", ""),
            "owner": l.get("owner_agent_name", ""),
            "count": len(events),
            "flagged": len(events) > 2,
        })
    rows.sort(key=lambda r: r["count"], reverse=True)
    return templates.TemplateResponse(request, "admin/deposit_watch.html",
                                      {"rows": rows, "window": window})


# ── 定金凭证审核(模块六 §5.3) ──

def _proof_src(deposit_proof_url: str) -> str:
    """把存的凭证值转成后台可显示的 <img src>。"""
    if not deposit_proof_url:
        return ""
    if deposit_proof_url.startswith("data:"):
        return deposit_proof_url  # base64 内联
    if "/photos/" in deposit_proof_url:
        key = deposit_proof_url.split("/photos/", 1)[1]
        return f"/admin/photo/{key}"
    return f"/admin/photo/{deposit_proof_url}"  # 裸 key


@admin_router.get("/photo/{key:path}")
def admin_photo_proxy(key: str, _: bool = Depends(require_admin)):
    """后台专用图片读取(cookie 鉴权;经纪人端 /api/v1/photos 需 JWT,后台用不了)。"""
    from starlette.responses import StreamingResponse
    from storage import get_photo, PhotoNotFound
    try:
        stream, content_type = get_photo(key)
    except PhotoNotFound:
        raise HTTPException(status_code=404, detail="照片不存在")
    return StreamingResponse(stream, media_type=content_type,
                             headers={"Cache-Control": "private, max-age=86400"})


@admin_router.get("/deposit-proofs", response_class=HTMLResponse)
def admin_deposit_proofs(request: Request, _: bool = Depends(require_admin), msg: str = ""):
    rows = []
    for l in db["listings"].find({"status": "deposit_paid"}).sort("deposit_paid_at", -1).limit(200):
        review = l.get("deposit_proof_review") or {}
        proof = l.get("deposit_proof_url", "")
        rows.append({
            "id": str(l["_id"]),
            "community": l.get("community", ""),
            "building": l.get("building", ""), "room_no": l.get("room_no", ""),
            "owner": l.get("owner_agent_name", ""),
            "amount": l.get("deposit_amount_yuan", "-"),
            "has_proof": bool(proof),
            "proof_src": _proof_src(proof),
            "reviewed": review.get("result", ""),
        })
    return templates.TemplateResponse(request, "admin/deposit_proofs.html", {"rows": rows, "msg": msg})


@admin_router.post("/listings/{listing_id}/review-proof")
def admin_review_proof(listing_id: str, _: bool = Depends(require_admin),
                       result: str = Form(...), reason: str = Form("")):
    """审核定金凭证:result=ok(合规)/reject(不合规)。不合规仅记录+留痕,处罚走踢出/争议。"""
    try:
        lid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源 ID")
    if not db["listings"].find_one({"_id": lid}):
        raise HTTPException(status_code=404, detail="房源不存在")
    result = result if result in ("ok", "reject") else "ok"
    db["listings"].update_one({"_id": lid}, {"$set": {"deposit_proof_review": {
        "result": result, "reason": reason.strip(), "at": datetime.now(),
    }, "updated_at": datetime.now()}})
    write_audit("deposit_proof_review", "listing", listing_id, {"result": result})
    return RedirectResponse(url=f"/admin/deposit-proofs?msg={quote('已审核')}",
                            status_code=status.HTTP_303_SEE_OTHER)


# ── 待确认成交管理(模块六 §7.6,只读监控) ──

def _fmt_deal_date(v) -> str:
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d")
    return str(v) if v else ""


@admin_router.get("/transactions", response_class=HTMLResponse)
def admin_transactions(request: Request, _: bool = Depends(require_admin), view: str = "pending"):
    now = datetime.now()
    if view == "mismatch":
        query = {"status": "rejected", "reject_kind": "price_mismatch"}
    elif view == "cancelled":
        query = {"status": "cancelled"}
    else:
        view = "pending"
        query = {"status": "pending_la_confirm"}

    rows = []
    for t in db["transactions"].find(query).sort("created_at", -1).limit(200):
        snap = t.get("listing_snapshot", {})
        created = t.get("ba_submitted_at") or t.get("created_at")
        wait_days = (now - created).days if isinstance(created, datetime) else None
        # 卡住判定:LA 被暂停/踢出 → 待确认无法推进,可代确认
        la_stuck = False
        if view == "pending":
            la = db["agents"].find_one({"_id": t.get("la_agent_id")}, {"status": 1})
            la_stuck = bool(la) and la.get("status") in ("suspended", "banned")
        rows.append({
            "id": str(t["_id"]),
            "community": snap.get("community", ""),
            "ba": t.get("ba_agent_name", ""),
            "la": t.get("la_agent_name", ""),
            "ba_price": t.get("ba_deal_price_yuan", ""),
            "ba_date": _fmt_deal_date(t.get("ba_deal_date")),
            "la_price": t.get("la_deal_price_yuan") or "-",
            "la_date": _fmt_deal_date(t.get("la_deal_date")) or "-",
            "wait_days": wait_days,
            "overdue": wait_days is not None and wait_days >= 6,
            "la_stuck": la_stuck,
            "reject_reason": t.get("reject_reason", ""),
            "cancel_reason": t.get("cancel_reason", ""),
        })
    return templates.TemplateResponse(request, "admin/transactions.html", {"rows": rows, "view": view})


# ── 代确认成交(模块六 §5.3,⚠️反作弊:B 模型,见 transactions.proxy_confirm_transaction) ──

@admin_router.get("/transactions/{tx_id}/proxy-confirm", response_class=HTMLResponse)
def admin_proxy_confirm_form(tx_id: str, request: Request, _: bool = Depends(require_admin), msg: str = ""):
    try:
        oid = ObjectId(tx_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的成交 ID")
    t = db["transactions"].find_one({"_id": oid})
    if not t:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    la = db["agents"].find_one({"_id": t.get("la_agent_id")}, {"status": 1, "name": 1})
    la_status = la.get("status") if la else None
    snap = t.get("listing_snapshot", {})
    # ⚠️ 故意不回显 BA 已提交的成交价/日期 —— admin 必须从真实合同独立录入,防止照抄
    ctx = {
        "id": str(oid),
        "community": snap.get("community", ""),
        "ba": t.get("ba_agent_name", ""),
        "la": t.get("la_agent_name", ""),
        "la_status": la_status,
        "stuck": la_status in ("suspended", "banned"),
        "status": t.get("status", ""),
        "msg": msg,
    }
    return templates.TemplateResponse(request, "admin/proxy_confirm.html", {"t": ctx})


@admin_router.post("/transactions/{tx_id}/proxy-confirm")
def admin_proxy_confirm(tx_id: str, _: bool = Depends(require_admin),
                        la_price_yuan: int = Form(...), la_date: str = Form(...), reason: str = Form(...)):
    from transactions import proxy_confirm_transaction
    res = proxy_confirm_transaction(tx_id, la_price_yuan, la_date, reason)
    write_audit("proxy_confirm", "transaction", tx_id,
                {"result": res["status"], "la_price_yuan": la_price_yuan})
    note = "代确认成功,成交已生效" if res["status"] == "confirmed" else "已代填,但与 BA 不一致,系统驳回(请核实真实成交值)"
    return RedirectResponse(url=f"/admin/transactions/{tx_id}/proxy-confirm?msg={quote(note)}",
                            status_code=status.HTTP_303_SEE_OTHER)


# ── 归属变更(模块六 §5.3:发起→锁定→复核→确认) ──

@admin_router.post("/listings/{listing_id}/ownership-change")
def admin_create_ownership_change(listing_id: str, _: bool = Depends(require_admin),
                                  to_phone: str = Form(...), proof: str = Form(""), reason: str = Form("")):
    from ownership import create_ownership_change
    res = create_ownership_change(listing_id, to_phone, proof, reason)
    write_audit("ownership_create", "listing", listing_id, {"to_phone": to_phone.strip()})
    return RedirectResponse(url=f"/admin/ownership-changes/{res['id']}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.get("/ownership-changes", response_class=HTMLResponse)
def admin_ownership_changes(request: Request, _: bool = Depends(require_admin), status_f: str = ""):
    from ownership import STATUS_LABEL
    query = {"status": status_f} if status_f else {}
    rows = []
    for c in db["ownership_changes"].find(query).sort("created_at", -1).limit(200):
        rows.append({
            "id": str(c["_id"]),
            "community": c.get("community", ""),
            "from_name": c.get("from_agent_name", ""),
            "to_name": c.get("to_agent_name", ""),
            "status": c.get("status", ""),
            "status_label": STATUS_LABEL.get(c.get("status", ""), c.get("status", "")),
            "created_at": c["created_at"].strftime("%Y-%m-%d %H:%M") if isinstance(c.get("created_at"), datetime) else "-",
        })
    return templates.TemplateResponse(request, "admin/ownership_changes.html",
                                      {"rows": rows, "status_f": status_f, "status_labels": STATUS_LABEL})


@admin_router.get("/ownership-changes/{change_id}", response_class=HTMLResponse)
def admin_ownership_detail(change_id: str, request: Request, _: bool = Depends(require_admin)):
    from ownership import STATUS_LABEL
    try:
        cid = ObjectId(change_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的变更 ID")
    c = db["ownership_changes"].find_one({"_id": cid})
    if not c:
        raise HTTPException(status_code=404, detail="归属变更不存在")
    d = {
        "id": str(cid),
        "community": c.get("community", ""),
        "from_name": c.get("from_agent_name", ""),
        "to_name": c.get("to_agent_name", ""),
        "to_phone": c.get("to_agent_phone", ""),
        "reason": c.get("reason", ""),
        "proof_src": _proof_src(c.get("proof", "")),
        "has_proof": bool(c.get("proof")),
        "status": c.get("status", ""),
        "status_label": STATUS_LABEL.get(c.get("status", ""), c.get("status", "")),
        "review_note": c.get("review_note", ""),
        "pending": c.get("status") == "pending_review",
    }
    return templates.TemplateResponse(request, "admin/ownership_detail.html", {"d": d})


@admin_router.post("/ownership-changes/{change_id}/approve")
def admin_ownership_approve(change_id: str, _: bool = Depends(require_admin)):
    from ownership import approve_ownership_change
    res = approve_ownership_change(change_id)
    write_audit("ownership_approve", "ownership_change", change_id, {"to": res.get("transferred_to", "")})
    return RedirectResponse(url=f"/admin/ownership-changes/{change_id}", status_code=status.HTTP_303_SEE_OTHER)


@admin_router.post("/ownership-changes/{change_id}/reject")
def admin_ownership_reject(change_id: str, _: bool = Depends(require_admin), note: str = Form("")):
    from ownership import reject_ownership_change
    reject_ownership_change(change_id, note)
    write_audit("ownership_reject", "ownership_change", change_id, {})
    return RedirectResponse(url=f"/admin/ownership-changes/{change_id}", status_code=status.HTTP_303_SEE_OTHER)


# ── 小区批量导入 / 导出(CSV) ──

@admin_router.get("/community-export.csv")
def admin_community_export(_: bool = Depends(require_admin), empty: int = 0):
    """空白模板导出:只给表头(无数据行),供从零批量录入后导入。

    不再一键全量导出——要导现有数据请到列表勾选后走 POST /community-export.csv。
    """
    from communities import COMMUNITY_RICH_FIELDS
    header = (["小区名", "区域", "备案名", "别名", "建成年代", "楼栋数"]
              + [f["label"] for f in COMMUNITY_RICH_FIELDS])
    write_audit("export", "communities", "-", {"mode": "template"})
    return _csv_response("communities_template.csv", header, [])


@admin_router.post("/community-export.csv")
async def admin_community_export_selected(request: Request, _: bool = Depends(require_admin)):
    """选择性导出:只导出列表里勾选的小区(表单字段 ids)。一个都没勾 → 只给表头。"""
    from communities import COMMUNITY_RICH_FIELDS
    form = await request.form()
    ids = form.getlist("ids")
    header = (["小区名", "区域", "备案名", "别名", "建成年代", "楼栋数"]
              + [f["label"] for f in COMMUNITY_RICH_FIELDS])
    oids = []
    for i in ids:
        try:
            oids.append(ObjectId(i))
        except Exception:
            continue
    rows = []
    if oids:
        for c in db["communities"].find({"_id": {"$in": oids}}).sort("name", 1):
            row = [c.get("name", ""), c.get("district", ""),
                   c.get("filing_name") or "", "、".join(c.get("aliases") or []),
                   c.get("built_year") or "", c.get("building_count") or ""]
            row += [c.get(f["key"]) if c.get(f["key"]) is not None else "" for f in COMMUNITY_RICH_FIELDS]
            rows.append(row)
    write_audit("export", "communities", "-", {"mode": "selected", "count": len(rows)})
    return _csv_response("communities.csv", header, rows)


@admin_router.post("/community-import")
async def admin_community_import(_: bool = Depends(require_admin), file: UploadFile = File(...)):
    """CSV 批量导入小区,按(小区名,区域)upsert。表头兼容中文 label 或英文 key(导出可直接回传)。"""
    from communities import COMMUNITY_RICH_FIELDS
    content = (await file.read()).decode("utf-8-sig", errors="replace")
    reader = csv.DictReader(io.StringIO(content))
    now = datetime.now()
    created = updated = skipped = 0

    def _pick(row, label, key):
        v = row.get(label)
        if v is None:
            v = row.get(key)
        return v

    for row in reader:
        name = (_pick(row, "小区名", "name") or "").strip()
        district = (_pick(row, "区域", "district") or "").strip()
        if not name or not district:
            skipped += 1
            continue
        doc = {
            "name": name, "district": district, "updated_at": now,
            "filing_name": (_pick(row, "备案名", "filing_name") or "").strip() or None,
            "aliases": _parse_aliases(_pick(row, "别名", "aliases")),
            "built_year": _coerce_field(_pick(row, "建成年代", "built_year"), "int"),
            "building_count": _coerce_field(_pick(row, "楼栋数", "building_count"), "int"),
        }
        for f in COMMUNITY_RICH_FIELDS:
            doc[f["key"]] = _coerce_field(_pick(row, f["label"], f["key"]), f["type"])
        existing = db["communities"].find_one({"name": name, "district": district})
        if existing:
            db["communities"].update_one({"_id": existing["_id"]}, {"$set": doc})
            updated += 1
        else:
            doc["created_at"] = now
            db["communities"].insert_one(doc)
            created += 1

    write_audit("community_import", "community", "-",
                {"created": created, "updated": updated, "skipped": skipped})
    msg = quote(f"导入完成:新增 {created} · 更新 {updated} · 跳过 {skipped}")
    return RedirectResponse(url=f"/admin/communities?msg={msg}", status_code=status.HTTP_303_SEE_OTHER)
