"""V2.5: Q&A 问答系统 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from datetime import datetime
from bson import ObjectId
from database import db
from utils.anonymize import anonymize_name


@pytest.fixture
def la_agent():
    return {"_id": str(ObjectId()), "name": "张三", "phone": "13800001111"}

@pytest.fixture
def ba_agent():
    return {"_id": str(ObjectId()), "name": "李红", "phone": "13200132000"}

@pytest.fixture
def listing(la_agent):
    lid = str(ObjectId())
    db["listings"].insert_one({
        "_id": ObjectId(lid), "listing_id": lid,
        "house_code": f"QNA{str(ObjectId())[-4:]}",
        "community": "中泰城", "building": "1", "unit": "1", "room_no": "101",
        "owner_agent_id": la_agent["_id"], "owner_agent_name": la_agent["name"],
        "district": "桥东区", "layout": "3室1厅", "orientation": "朝南",
        "price_wan": 100, "status": "on_sale",
        "sale_points": [], "public_remarks": "", "agent_remarks": "",
        "showing_instructions": "", "photo_count": 0, "photos": [],
        "bonus_yuan": 0, "cover_thumbnail": None,
        "created_at": datetime.now(), "updated_at": datetime.now(),
    })
    yield lid
    db["qna_threads"].delete_many({"listing_id": lid})
    db["listings"].delete_one({"_id": ObjectId(lid)})


# ═══════════════════ Tests ═══════════════════

def test_anonymize_name():
    assert anonymize_name("李红") == "李*"
    assert anonymize_name("张") == "张*"
    assert anonymize_name("") == "匿*"


def test_ba_can_ask(listing, ba_agent):
    """BA 对他人房源发问 → 200,返回 thread_id"""
    from qna import ask_qna, AskQnaBody
    tid = str(listing)
    result = ask_qna(tid, AskQnaBody(question="满五唯一吗?"), ba_agent)
    assert result["success"]
    assert "thread_id" in result["data"]

    # 验证落库
    t = db["qna_threads"].find_one({"thread_id": result["data"]["thread_id"]})
    assert t["status"] == "pending"
    assert t["question"] == "满五唯一吗?"


def test_la_can_answer(listing, la_agent, ba_agent):
    """LA 回答自己房源的问题 → 200,状态变 answered"""
    from qna import ask_qna, answer_qna, AskQnaBody, AnswerQnaBody
    r1 = ask_qna(str(listing), AskQnaBody(question="户型怎么样?"), ba_agent)
    tid = r1["data"]["thread_id"]

    r2 = answer_qna(tid, AnswerQnaBody(answer="南北通透,全明格局"), la_agent)
    assert r2["success"]

    t = db["qna_threads"].find_one({"thread_id": tid})
    assert t["status"] == "answered"
    assert t["answer"] == "南北通透,全明格局"


def test_ba_pending_limit(listing, ba_agent):
    """BA 对同房源 4 个 pending → 第4个 400"""
    from qna import ask_qna, AskQnaBody
    from fastapi import HTTPException
    tid = str(listing)
    for i in range(3):
        ask_qna(tid, AskQnaBody(question=f"问题{i}"), ba_agent)

    with pytest.raises(HTTPException) as exc:
        ask_qna(tid, AskQnaBody(question="问题4"), ba_agent)
    assert exc.value.status_code == 400


def test_anonymous_name_in_list(listing, la_agent, ba_agent):
    """BA 视角列表 asker_name 显"李*",LA 视角显"李红" """
    from qna import ask_qna, list_qna, AskQnaBody
    ask_qna(str(listing), AskQnaBody(question="采光好吗?"), ba_agent)

    # BA 视角
    r_ba = list_qna(str(listing), agent=ba_agent)  # type: ignore
    items_ba = r_ba["data"]["items"]
    assert len(items_ba) >= 1
    assert items_ba[0]["asker_name"] == "李*"

    # LA 视角
    r_la = list_qna(str(listing), agent=la_agent)  # type: ignore
    items_la = r_la["data"]["items"]
    assert items_la[0]["asker_name"] == "李红"
