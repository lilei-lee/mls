"""Q&A 问答系统 — BA 提问题, LA 回答"""
import uuid
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from bson import ObjectId

from database import db
from utils.anonymize import anonymize_name

# Auth dependency — lazy import to avoid circular
def _get_agent():
    from main import get_current_agent
    return get_current_agent

qna_router = APIRouter(prefix="/api/v1", tags=["qna"])

MAX_PENDING_PER_ASKER = 3
QUESTION_MAX = 200
ANSWER_MAX = 300


# ═══════════════════ Request models ═══════════════════

class AskQnaBody(BaseModel):
    question: str = Field(..., min_length=1, max_length=QUESTION_MAX)

class AnswerQnaBody(BaseModel):
    answer: str = Field(..., min_length=1, max_length=ANSWER_MAX)


# ═══════════════════ Helpers ═══════════════════

def _ok(data: dict) -> dict:
    return {"success": True, "data": data}

def _is_owner(listing_doc, user_id) -> bool:
    return str(listing_doc.get("owner_agent_id", "")) == str(user_id)


# ═══════════════════ API 1: 列表 ═══════════════════

@qna_router.get("/listings/{listing_id}/qna")
def list_qna(
    listing_id: str,
    limit: int = 20,
    offset: int = 0,
    status: str = "all",
    agent = Depends(_get_agent()),  # noqa: F821
):
    try:
        lid_oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    listing = db["listings"].find_one({"_id": lid_oid})
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")

    is_owner = _is_owner(listing, agent["_id"])

    query: dict = {"listing_id": listing_id}
    if status in ("pending", "answered"):
        query["status"] = status
    elif not is_owner:
        query["status"] = {"$ne": "deleted"}

    total = db["qna_threads"].count_documents(query)
    threads = list(
        db["qna_threads"].find(query)
        .sort("question_at", -1)
        .skip(offset)
        .limit(limit)
    )

    items = []
    for t in threads:
        items.append({
            "thread_id": t["thread_id"],
            "question": t["question"],
            "question_at": t["question_at"].isoformat() if t.get("question_at") else None,
            "asker_name": t["asker_name"] if (is_owner or str(t.get("asker_id", "")) == str(agent["_id"])) else t.get("asker_anonymous_name", ""),
            "asker_id_self": str(t.get("asker_id", "")) == str(agent["_id"]),
            "status": t["status"],
            "answer": t.get("answer"),
            "answered_at": t["answered_at"].isoformat() if t.get("answered_at") else None,
            "answerer_name": t.get("answerer_name"),
            "answerer_self": str(t.get("answerer_id", "")) == str(agent["_id"]),
            "can_delete": str(t.get("asker_id", "")) == str(agent["_id"]) or is_owner,
        })

    brief = {
        "community": listing.get("community", ""),
        "building": listing.get("building", ""),
        "unit": listing.get("unit", ""),
        "room_no": listing.get("room_no", ""),
    }

    return _ok({"total": total, "items": items, "listing_brief": brief})


# ═══════════════════ API 2: 提问 ═══════════════════

@qna_router.post("/listings/{listing_id}/qna")
def ask_qna(listing_id: str, body: AskQnaBody, agent = Depends(_get_agent())):  # noqa: F821
    try:
        lid_oid = ObjectId(listing_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源ID")

    listing = db["listings"].find_one({"_id": lid_oid})
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")

    # 不能问自己
    if _is_owner(listing, agent["_id"]):
        raise HTTPException(status_code=400, detail="不能向自己的房源提问")

    # 限制 pending 数量
    pending_count = db["qna_threads"].count_documents({
        "listing_id": listing_id,
        "asker_id": str(agent["_id"]),
        "status": "pending",
    })
    if pending_count >= MAX_PENDING_PER_ASKER:
        raise HTTPException(status_code=400, detail="请先等之前的问题被回答")

    now = datetime.now()
    thread_id = str(uuid.uuid4())[:12]
    doc = {
        "thread_id": thread_id,
        "listing_id": listing_id,
        "community": listing.get("community", ""),
        "asker_id": str(agent["_id"]),
        "asker_name": agent.get("name", ""),
        "asker_anonymous_name": anonymize_name(agent.get("name", "")),
        "question": body.question.strip(),
        "question_at": now,
        "status": "pending",
        "answerer_id": str(listing["owner_agent_id"]),
        "answerer_name": listing.get("owner_agent_name", ""),
        "answer": None,
        "answered_at": None,
        "view_count": 0,
        "created_at": now,
        "updated_at": now,
    }
    db["qna_threads"].insert_one(doc)

    return _ok({
        "thread_id": thread_id,
        "question_at": now.isoformat(),
        "asker_anonymous_name": doc["asker_anonymous_name"],
    })


# ═══════════════════ API 3: 回答 ═══════════════════

@qna_router.post("/qna/{thread_id}/answer")
def answer_qna(thread_id: str, body: AnswerQnaBody, agent = Depends(_get_agent())):  # noqa: F821
    thread = db["qna_threads"].find_one({"thread_id": thread_id})
    if not thread:
        raise HTTPException(status_code=404, detail="问答不存在")
    if thread["status"] != "pending":
        raise HTTPException(status_code=400, detail="该问答不是待回答状态")

    # 必须是该 listing 的 owner
    listing = db["listings"].find_one({"_id": ObjectId(thread["listing_id"])}) if thread.get("listing_id") else None
    if not listing or not _is_owner(listing, agent["_id"]):
        raise HTTPException(status_code=403, detail="只有房源归属人可以回答问题")

    now = datetime.now()
    db["qna_threads"].update_one(
        {"thread_id": thread_id},
        {"$set": {
            "answer": body.answer.strip(),
            "answered_at": now,
            "status": "answered",
            "answerer_id": str(agent["_id"]),
            "answerer_name": agent.get("name", ""),
            "updated_at": now,
        }}
    )

    return _ok({"answered_at": now.isoformat()})


# ═══════════════════ API 4: 删除 ═══════════════════

@qna_router.delete("/qna/{thread_id}")
def delete_qna(thread_id: str, agent = Depends(_get_agent())):  # noqa: F821
    thread = db["qna_threads"].find_one({"thread_id": thread_id})
    if not thread:
        raise HTTPException(status_code=404, detail="问答不存在")

    is_asker = str(thread.get("asker_id", "")) == str(agent["_id"])
    listing = db["listings"].find_one({"_id": ObjectId(thread["listing_id"])}) if thread.get("listing_id") else None
    is_owner = listing and _is_owner(listing, agent["_id"])

    # BA 只能删自己 pending 的
    if is_asker and thread["status"] != "pending":
        raise HTTPException(status_code=400, detail="已回答的问题不能删除")

    if not is_asker and not is_owner:
        raise HTTPException(status_code=403, detail="无权删除此问答")

    db["qna_threads"].update_one(
        {"thread_id": thread_id},
        {"$set": {"status": "deleted", "updated_at": datetime.now()}}
    )
    return {"success": True, "message": "已删除"}
