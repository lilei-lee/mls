"""customers._format_customer 纯单测 — 不依赖 MongoDB。

锁定对前端的容错契约:phone/requirements 缺失返空串而非 null/KeyError,
日期 isoformat,memo_entries 缺失返空列表。
"""
from datetime import datetime
from bson import ObjectId

from customers import _format_customer


def _make_doc(**override):
    doc = {
        "_id": ObjectId(),
        "surname": "王",
        "gender": "male",
        "phone": "13900001111",
        "requirements": "两室,预算100万",
        "memo_entries": [{"text": "看过一次"}],
        "status": "active",
        "created_at": datetime(2026, 5, 1, 10, 0, 0),
        "updated_at": datetime(2026, 5, 2, 11, 0, 0),
    }
    doc.update(override)
    return doc


def test_basic_fields():
    out = _format_customer(_make_doc())
    assert out["surname"] == "王"
    assert out["gender"] == "male"
    assert out["phone"] == "13900001111"
    assert out["status"] == "active"
    assert out["created_at"] == "2026-05-01T10:00:00"
    assert out["updated_at"] == "2026-05-02T11:00:00"
    assert out["customer_id"] == str(_make_doc()["_id"]) or isinstance(out["customer_id"], str)


def test_phone_none_becomes_empty_string():
    """phone 为 None → 返空串(前端不必判 null)"""
    assert _format_customer(_make_doc(phone=None))["phone"] == ""


def test_requirements_none_becomes_empty_string():
    assert _format_customer(_make_doc(requirements=None))["requirements"] == ""


def test_missing_memo_entries_defaults_empty_list():
    doc = _make_doc()
    del doc["memo_entries"]
    assert _format_customer(doc)["memo_entries"] == []


def test_missing_dates_return_none():
    doc = _make_doc()
    del doc["created_at"]
    del doc["updated_at"]
    out = _format_customer(doc)
    assert out["created_at"] is None
    assert out["updated_at"] is None


def test_customer_id_is_str_of_oid():
    oid = ObjectId()
    out = _format_customer(_make_doc(_id=oid))
    assert out["customer_id"] == str(oid)
