"""showings 格式化器纯单测 — 不依赖 MongoDB。

锁定两条关键契约:
1. 列表轻量版 _format_showing_lite 绝不返回 photos 大字段(性能 + 流量)
2. Day 16 容错:直接带看路径可能漏写 ba_submitted_at 等字段,formatter
   必须用 .get 容错,缺字段返默认值而非 KeyError。
"""
from datetime import datetime
from bson import ObjectId

from showings import _format_showing, _format_showing_lite, _iso_or_none


def _full_doc():
    now = datetime(2026, 5, 6, 14, 0, 0)
    return {
        "_id": ObjectId(),
        "showing_request_id": ObjectId(),
        "listing_id": ObjectId(),
        "listing_snapshot": {"community": "中泰城"},
        "ba_agent_name": "李红",
        "la_agent_name": "张三",
        "showing_time": now,
        "photos": ["data:image/jpeg;base64,AAA", "data:image/jpeg;base64,BBB"],
        "photo_count": 2,
        "notes": "客户满意",
        "status": "confirmed",
        "reject_reason": None,
        "ba_submitted_at": now,
        "la_reviewed_at": now,
        "is_repeat_showing": True,
        "original_request_id": ObjectId(),
    }


def _minimal_doc():
    """模拟 Day 15 直接带看漏写部分字段的脏文档(只有必需字段)。"""
    return {
        "_id": ObjectId(),
        "showing_request_id": ObjectId(),
        "listing_id": ObjectId(),
        "status": "pending_confirm",
    }


# ── _iso_or_none ─────────────────────────────────────────────

def test_iso_or_none_with_none():
    assert _iso_or_none(None) is None


def test_iso_or_none_with_datetime():
    assert _iso_or_none(datetime(2026, 5, 6, 14, 0, 0)) == "2026-05-06T14:00:00"


# ── 详情版含 photos,轻量版不含 ──────────────────────────────

def test_full_format_includes_photos():
    out = _format_showing(_full_doc())
    assert out["photos"] == ["data:image/jpeg;base64,AAA", "data:image/jpeg;base64,BBB"]
    assert out["photo_count"] == 2


def test_lite_format_excludes_photos():
    """列表版绝不能带 photos 大数据 —— 核心性能契约"""
    out = _format_showing_lite(_full_doc())
    assert "photos" not in out
    assert out["photo_count"] == 2  # 数量还是给的


def test_full_format_repeat_showing_fields():
    doc = _full_doc()
    out = _format_showing(doc)
    assert out["is_repeat_showing"] is True
    assert out["original_request_id"] == str(doc["original_request_id"])


# ── Day 16 容错:脏文档不崩 ──────────────────────────────────

def test_full_format_tolerates_missing_fields():
    out = _format_showing(_minimal_doc())
    assert out["ba_agent_name"] == ""
    assert out["notes"] == ""
    assert out["photo_count"] == 0
    assert out["photos"] == []
    assert out["showing_time"] is None
    assert out["ba_submitted_at"] is None
    assert out["is_repeat_showing"] is False
    assert out["original_request_id"] is None


def test_lite_format_tolerates_missing_fields():
    out = _format_showing_lite(_minimal_doc())
    assert out["ba_agent_name"] == ""
    assert out["photo_count"] == 0
    assert out["showing_time"] is None
    assert out["ba_submitted_at"] is None
