"""带看客户反馈(阶段2)纯单测 — 不依赖 MongoDB。"""
import pytest
from pydantic import ValidationError

from showings import (
    CreateShowingBody, feedback_fields_from, _format_showing,
    SATISFACTION_OPTIONS, INTENT_RESULT_OPTIONS,
)


def _body(**override):
    base = dict(
        showing_request_id="rid", showing_time="2026-05-06T14:00:00",
        photos=["data:image/jpeg;base64,AAA"],
    )
    base.update(override)
    return CreateShowingBody(**base)


def test_feedback_optional_defaults_none():
    fb = feedback_fields_from(_body())
    assert fb == {"satisfaction": None, "customer_feedback": "",
                  "true_needs": "", "intent_result": None}


def test_feedback_full_extraction_and_strip():
    fb = feedback_fields_from(_body(
        satisfaction="满意", customer_feedback="  喜欢  ",
        true_needs=" 要学区 ", intent_result="有意"))
    assert fb["satisfaction"] == "满意"
    assert fb["customer_feedback"] == "喜欢"   # 去空白
    assert fb["true_needs"] == "要学区"
    assert fb["intent_result"] == "有意"


@pytest.mark.parametrize("field,bad", [
    ("satisfaction", "很满意"),
    ("intent_result", "想要"),
])
def test_feedback_enum_rejects_invalid(field, bad):
    with pytest.raises(ValidationError):
        _body(**{field: bad})


def test_satisfaction_accepts_all_options():
    for s in SATISFACTION_OPTIONS:
        assert _body(satisfaction=s).satisfaction == s


def test_intent_result_accepts_all_options():
    for r in INTENT_RESULT_OPTIONS:
        assert _body(intent_result=r).intent_result == r


def test_customer_feedback_too_long_rejected():
    with pytest.raises(ValidationError):
        _body(customer_feedback="x" * 301)


def test_true_needs_too_long_rejected():
    with pytest.raises(ValidationError):
        _body(true_needs="x" * 301)


def test_format_showing_surfaces_feedback():
    from datetime import datetime
    from bson import ObjectId
    doc = {
        "_id": ObjectId(), "showing_request_id": ObjectId(), "listing_id": ObjectId(),
        "status": "confirmed", "showing_time": datetime(2026, 5, 6),
        "satisfaction": "一般", "customer_feedback": "还行",
        "true_needs": "预算偏低", "intent_result": "再看看",
    }
    out = _format_showing(doc)
    assert out["satisfaction"] == "一般"
    assert out["customer_feedback"] == "还行"
    assert out["true_needs"] == "预算偏低"
    assert out["intent_result"] == "再看看"


def test_format_showing_feedback_defaults_on_legacy_doc():
    from bson import ObjectId
    doc = {
        "_id": ObjectId(), "showing_request_id": ObjectId(), "listing_id": ObjectId(),
        "status": "pending_confirm",
    }
    out = _format_showing(doc)
    assert out["satisfaction"] is None
    assert out["customer_feedback"] == ""
    assert out["intent_result"] is None
