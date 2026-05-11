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
    """BA 自看全名'李红', LA 看全名'李红', 其他 BA 看脱敏'李*' """
    from qna import ask_qna, list_qna, AskQnaBody
    ask_qna(str(listing), AskQnaBody(question="采光好吗?"), ba_agent)

    # BA 自己看 → 全名
    r_self = list_qna(str(listing), agent=ba_agent)
    assert r_self["data"]["items"][0]["asker_name"] == "李红"

    # LA 视角 → 全名
    r_la = list_qna(str(listing), agent=la_agent)
    assert r_la["data"]["items"][0]["asker_name"] == "李红"

    # 其他 BA 视角 → 脱敏
    ba2 = {"_id": str(ObjectId()), "name": "王芳", "phone": "13300000000"}
    r_ba2 = list_qna(str(listing), agent=ba2)
    assert r_ba2["data"]["items"][0]["asker_name"] == "李*"


def test_ba2_sees_anonymized_name(listing, la_agent, ba_agent):
    """BA1 提问,BA2 查看 → asker_name='李*' """
    from qna import ask_qna, list_qna, AskQnaBody
    ask_qna(str(listing), AskQnaBody(question="能看房吗?"), ba_agent)

    ba2 = {"_id": str(ObjectId()), "name": "王芳", "phone": "13300000000"}
    r = list_qna(str(listing), agent=ba2)  # type: ignore
    assert r["data"]["items"][0]["asker_name"] == "李*"


def test_asker_sees_own_full_name(listing, la_agent, ba_agent):
    """BA1 提问后自己看 → asker_name='李红'(全名,不脱敏自己)"""
    from qna import ask_qna, list_qna, AskQnaBody
    ask_qna(str(listing), AskQnaBody(question="户型怎么样?"), ba_agent)

    r = list_qna(str(listing), agent=ba_agent)  # type: ignore
    assert r["data"]["items"][0]["asker_name"] == "李红"


def test_pending_limit_boundary(listing, ba_agent):
    """3 次成功,第 4 次 400"""
    from qna import ask_qna, AskQnaBody
    from fastapi import HTTPException
    for i in range(3):
        ask_qna(str(listing), AskQnaBody(question=f"边界问题{i}"), ba_agent)

    # 第 4 次应 reject
    with pytest.raises(HTTPException) as exc:
        ask_qna(str(listing), AskQnaBody(question="第4个问题"), ba_agent)
    assert exc.value.status_code == 400


def test_pending_limit_3rd_accepted(listing, ba_agent):
    """第 3 次 accept(边界),总数 3"""
    from qna import ask_qna, AskQnaBody
    for i in range(2):
        ask_qna(str(listing), AskQnaBody(question=f"前{i}"), ba_agent)

    # 第 3 次应 accept
    result = ask_qna(str(listing), AskQnaBody(question="第3个"), ba_agent)
    assert result["success"]


# ═══════════════════ API 5: 我的提问 ═══════════════════

def test_my_qna_ba_returns_own(listing, ba_agent):
    """BA 调用 /qna/my 返回自己的提问"""
    from qna import ask_qna, list_my_qna, AskQnaBody
    ask_qna(str(listing), AskQnaBody(question="我的提问测试"), ba_agent)

    r = list_my_qna(agent=ba_agent)  # type: ignore
    items = r["data"]["items"]
    assert len(items) >= 1
    assert items[0]["status"] == "pending"


def test_my_qna_la_returns_empty(listing, la_agent):
    """LA 调用 /qna/my 返回空数组"""
    from qna import list_my_qna
    r = list_my_qna(agent=la_agent)  # type: ignore
    assert r["data"]["items"] == []


def test_my_qna_sorting(listing, ba_agent, la_agent):
    """pending 在前,组内时间倒序"""
    from qna import ask_qna, answer_qna, list_my_qna, AskQnaBody, AnswerQnaBody
    ask_qna(str(listing), AskQnaBody(question="新问题"), ba_agent)
    r1 = ask_qna(str(listing), AskQnaBody(question="早问题"), ba_agent)

    # 回答 早问题,使其变 answered
    answer_qna(r1["data"]["thread_id"], AnswerQnaBody(answer="已回答"), la_agent)

    items = list_my_qna(agent=ba_agent)["data"]["items"]  # type: ignore
    statuses = [i["status"] for i in items]
    # pending 必须在前面
    pending_end = statuses.index("answered") if "answered" in statuses else len(statuses)
    assert all(s == "pending" for s in statuses[:pending_end])


def test_my_qna_deleted_not_included(listing, ba_agent):
    """软删 thread 不出现在列表中"""
    from qna import ask_qna, delete_qna, list_my_qna, AskQnaBody
    r = ask_qna(str(listing), AskQnaBody(question="待删"), ba_agent)
    delete_qna(r["data"]["thread_id"], agent=ba_agent)  # type: ignore

    items = list_my_qna(agent=ba_agent)["data"]["items"]  # type: ignore
    tids = [i["thread_id"] for i in items]
    assert r["data"]["thread_id"] not in tids


def test_pending_count_consistency(listing, ba_agent):
    """两个接口(pending-count / dashboard)返回相同 pending 数"""
    from qna import ask_qna, my_pending_count, _count_ba_pending_questions, AskQnaBody
    for i in range(2):
        ask_qna(str(listing), AskQnaBody(question=f"一致性{i}"), ba_agent)

    # 方式 1: HTTP 接口
    r1 = my_pending_count(agent=ba_agent)  # type: ignore
    # 方式 2: 公共函数
    r2 = _count_ba_pending_questions(ba_agent["_id"])
    assert r1["data"]["count"] == 2
    assert r2 == 2
