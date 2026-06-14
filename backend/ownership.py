"""房源归属变更(模块六 §5.3):上传凭证 → 房源锁定 → 管理员复核 → 确认转/不转。

种子期管理员驱动:admin 发起请求(目标经纪人 + 委托凭证 + 理由)→ 锁定房源 →
admin 复核(看凭证)→ 确认(转移归属 + 解锁 + 历史)或驳回(解锁)。
经纪人端凭证上传 UI 登债;当前 admin 录入 proof(MinIO key 或 url)。

护栏(不碰反作弊基石,但守 in-flight 交易):
- 房源非 sold(终态)
- 无进行中成交(pending_la_confirm)——发起 + 通过两次都校验(设计稿 V4 二次校验)
- 目标经纪人存在且 active(被踢出/暂停的不接房源)
- 同一房源同时只允许一个待复核请求(ownership_locked)
"""
from datetime import datetime

from bson import ObjectId
from fastapi import HTTPException

from database import db

STATUS_LABEL = {"pending_review": "待复核", "approved": "已转移", "rejected": "已驳回"}


def _has_active_tx(listing_id: ObjectId) -> bool:
    return db["transactions"].count_documents(
        {"listing_id": listing_id, "status": "pending_la_confirm"}) > 0


def _check_transferable(listing: dict, lid: ObjectId):
    if listing.get("status") == "sold":
        raise HTTPException(status_code=400, detail="已成交房源不可变更归属")
    if _has_active_tx(lid):
        raise HTTPException(status_code=400, detail="该房源有进行中的成交,不可变更归属")


def create_ownership_change(listing_id_str: str, to_phone: str, proof: str, reason: str,
                            requester_agent_id=None) -> dict:
    """发起归属变更请求 + 锁定房源。

    requester_agent_id:经纪人端发起时传(强制 = 当前归属人本人);
    后台 admin 发起时传 None(不校验发起人)。
    """
    try:
        lid = ObjectId(listing_id_str)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源 ID")
    listing = db["listings"].find_one({"_id": lid})
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")
    if requester_agent_id is not None and listing.get("owner_agent_id") != requester_agent_id:
        raise HTTPException(status_code=403, detail="只能对自己归属的房源发起归属变更")
    if listing.get("ownership_locked"):
        raise HTTPException(status_code=400, detail="该房源已有待复核的归属变更")
    _check_transferable(listing, lid)
    to_agent = db["agents"].find_one({"phone": to_phone.strip()})
    if not to_agent:
        raise HTTPException(status_code=400, detail="目标经纪人不存在")
    if to_agent.get("status") != "active":
        raise HTTPException(status_code=400, detail="目标经纪人非正常状态,不能接收房源")
    if to_agent["_id"] == listing.get("owner_agent_id"):
        raise HTTPException(status_code=400, detail="目标与当前归属人相同")
    # 委托凭证强制开关(种子期默认 0=不强制;设 1 后必须上传)
    from system_config import get_config
    if get_config("ownership_require_proof", 0) and not proof.strip():
        raise HTTPException(status_code=400, detail="已开启委托凭证强制,请先上传委托凭证")

    doc = {
        "listing_id": lid,
        "from_agent_id": listing.get("owner_agent_id"),
        "from_agent_name": listing.get("owner_agent_name", ""),
        "to_agent_id": to_agent["_id"],
        "to_agent_name": to_agent.get("name", ""),
        "to_agent_phone": to_agent.get("phone", ""),
        "community": listing.get("community", ""),
        "proof": proof.strip(),
        "reason": reason.strip(),
        "status": "pending_review",
        "created_at": datetime.now(),
        "handled_at": None,
        "review_note": "",
    }
    res = db["ownership_changes"].insert_one(doc)
    db["listings"].update_one({"_id": lid}, {"$set": {
        "ownership_locked": True, "ownership_change_id": res.inserted_id,
        "updated_at": datetime.now(),
    }})
    return {"id": str(res.inserted_id)}


def approve_ownership_change(change_id_str: str) -> dict:
    cid, c = _get_pending(change_id_str)
    lid = c["listing_id"]
    listing = db["listings"].find_one({"_id": lid})
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")
    # 二次校验(设计稿 V4):执行前再查一遍 in-flight 交易 + 目标仍 active
    _check_transferable(listing, lid)
    to_agent = db["agents"].find_one({"_id": c["to_agent_id"]})
    if not to_agent or to_agent.get("status") != "active":
        raise HTTPException(status_code=400, detail="目标经纪人已不可接收(非 active),已中止")

    now = datetime.now()
    db["listings"].update_one({"_id": lid}, {
        "$set": {
            "owner_agent_id": to_agent["_id"],
            "owner_agent_name": to_agent.get("name", ""),
            "owner_agent_phone": to_agent.get("phone", ""),
            "ownership_locked": False,
            "ownership_change_id": None,
            "updated_at": now,
        },
        "$push": {"owner_change_history": {
            "from_id": c.get("from_agent_id"), "from_name": c.get("from_agent_name", ""),
            "to_id": to_agent["_id"], "to_name": to_agent.get("name", ""),
            "reason": c.get("reason", ""), "at": now,
        }},
    })
    db["ownership_changes"].update_one({"_id": cid}, {"$set": {"status": "approved", "handled_at": now}})
    return {"transferred_to": to_agent.get("name", "")}


def reject_ownership_change(change_id_str: str, note: str) -> dict:
    cid, c = _get_pending(change_id_str)
    now = datetime.now()
    db["listings"].update_one({"_id": c["listing_id"]}, {"$set": {
        "ownership_locked": False, "ownership_change_id": None, "updated_at": now}})
    db["ownership_changes"].update_one({"_id": cid}, {"$set": {
        "status": "rejected", "review_note": note.strip(), "handled_at": now}})
    return {"ok": True}


def _get_pending(change_id_str: str):
    try:
        cid = ObjectId(change_id_str)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的变更 ID")
    c = db["ownership_changes"].find_one({"_id": cid})
    if not c:
        raise HTTPException(status_code=404, detail="归属变更不存在")
    if c.get("status") != "pending_review":
        raise HTTPException(status_code=400, detail="该归属变更已处理")
    return cid, c


def ensure_ownership_indexes():
    db["ownership_changes"].create_index("status")
    db["ownership_changes"].create_index("listing_id")
