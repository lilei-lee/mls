"""settlements 格式化器纯单测 — 不依赖 MongoDB。

settlement 是成交后的奖金单(无保密必要,双方互看完整),但 formatter 仍要
按视角返 viewer_role,且列表版的 counterpart_name 要随视角取对方姓名。
"""
from datetime import datetime
from bson import ObjectId

from settlements import _format, _format_lite


LA_ID = ObjectId()
BA_ID = ObjectId()
OTHER_ID = ObjectId()


def _make_doc():
    now = datetime(2026, 5, 8, 9, 0, 0)
    return {
        "_id": ObjectId(),
        "transaction_id": ObjectId(),
        "listing_id": ObjectId(),
        "listing_snapshot": {"community": "中泰城"},
        "la_agent_id": LA_ID,
        "ba_agent_id": BA_ID,
        "la_agent_name": "张三",
        "ba_agent_name": "李红",
        "bonus_yuan": 3000,
        "deal_price_yuan": 1_000_000,
        "deal_date": datetime(2026, 5, 6),
        "status": "pending_payment",
        "la_paid_at": None,
        "la_payment_note": None,
        "ba_received_at": None,
        "ba_receipt_note": None,
        "settled_at": None,
        "created_at": now,
    }


# ── _format viewer_role ──────────────────────────────────────

def test_format_viewer_role_la():
    out = _format(_make_doc(), viewer_id=LA_ID)
    assert out["viewer_role"] == "la"
    assert out["bonus_yuan"] == 3000
    assert out["deal_date"] == "2026-05-06"


def test_format_viewer_role_ba():
    assert _format(_make_doc(), viewer_id=BA_ID)["viewer_role"] == "ba"


def test_format_viewer_role_none_for_third_party():
    assert _format(_make_doc(), viewer_id=OTHER_ID)["viewer_role"] is None


def test_format_viewer_role_none_when_no_viewer():
    assert _format(_make_doc())["viewer_role"] is None


def test_format_deal_date_none_safe():
    doc = _make_doc()
    doc["deal_date"] = None
    assert _format(doc, LA_ID)["deal_date"] is None


# ── _format_lite counterpart_name 随视角取对方 ───────────────

def test_lite_la_sees_ba_as_counterpart():
    """LA 视角 → counterpart 是 BA(李红)"""
    out = _format_lite(_make_doc(), viewer_id=LA_ID)
    assert out["counterpart_name"] == "李红"
    assert out["viewer_role"] == "la"


def test_lite_ba_sees_la_as_counterpart():
    """BA 视角 → counterpart 是 LA(张三),双向取反"""
    out = _format_lite(_make_doc(), viewer_id=BA_ID)
    assert out["counterpart_name"] == "张三"
    assert out["viewer_role"] == "ba"


def test_lite_omits_heavy_fields():
    """列表轻量版不应带 listing 大字段以外的明细(无 la_payment_note 等)"""
    out = _format_lite(_make_doc(), viewer_id=LA_ID)
    assert "la_payment_note" not in out
    assert "ba_receipt_note" not in out
