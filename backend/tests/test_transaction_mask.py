"""反作弊基石回归保护 — transactions._format 的 viewer-aware 脱敏单测。

纯函数测试,不依赖 MongoDB。锁死 CLAUDE.md 铁律 4 / 经验 5 / 经验 6:
- mask 按"业务保密区间"(status != confirmed)设计,不按单一瞬间
- mask 必须双向(LA 看 BA、BA 看 LA 都脱敏)
- 第三方 / 无 viewer 的行为明确
- 必返 viewer_role,前端据此判身份(不靠姓名兜底)
"""
from datetime import datetime
from bson import ObjectId

from transactions import _format


LA_ID = ObjectId()
BA_ID = ObjectId()
THIRD_ID = ObjectId()


def _make_doc(status="pending_la_confirm"):
    """构造一条双方都已填报的 transaction 文档。"""
    now = datetime(2026, 5, 6, 14, 0, 0)
    return {
        "_id": ObjectId(),
        "showing_id": ObjectId(),
        "showing_request_id": ObjectId(),
        "listing_id": ObjectId(),
        "listing_snapshot": {"community": "中泰城"},
        "ba_agent_id": BA_ID,
        "la_agent_id": LA_ID,
        "ba_agent_name": "李红",
        "la_agent_name": "张三",
        "ba_deal_price_yuan": 1_010_000,
        "ba_deal_date": datetime(2026, 5, 6),
        "ba_notes": "BA 私密备注",
        "ba_submitted_at": now,
        "ba_updated_at": now,
        "la_deal_price_yuan": 1_000_000,
        "la_deal_date": datetime(2026, 5, 5),
        "la_submitted_at": now,
        "status": status,
        "reject_kind": None,
        "reject_reason": None,
        "cancel_reason": None,
        "confirmed_at": now if status == "confirmed" else None,
        "rejected_at": None,
        "cancelled_at": None,
        "created_at": now,
    }


# ── 保密区间内:双向脱敏 ──────────────────────────────────────

def test_la_cannot_see_ba_fields_when_pending():
    """LA 视角 + pending → BA 填报全脱敏,自己的 LA 填报可见"""
    out = _format(_make_doc("pending_la_confirm"), viewer_id=LA_ID)
    assert out["ba_deal_price_yuan"] is None
    assert out["ba_deal_date"] is None
    assert out["ba_notes"] == ""
    # 自己填的看得见
    assert out["la_deal_price_yuan"] == 1_000_000
    assert out["la_deal_date"] == "2026-05-05"
    assert out["viewer_role"] == "la"
    # 不泄露价格,但可知道对方已提交
    assert out["ba_has_submitted"] is True


def test_ba_cannot_see_la_fields_when_pending():
    """BA 视角 + pending → LA 填报全脱敏(双向 mask)"""
    out = _format(_make_doc("pending_la_confirm"), viewer_id=BA_ID)
    assert out["la_deal_price_yuan"] is None
    assert out["la_deal_date"] is None
    assert out["la_submitted_at"] is None
    # 自己填的看得见
    assert out["ba_deal_price_yuan"] == 1_010_000
    assert out["ba_deal_date"] == "2026-05-06"
    assert out["viewer_role"] == "ba"


# ── 经验 5:保密区间是状态集合,不是单一瞬间 ──────────────────

def test_la_still_masked_when_rejected():
    """rejected 仍属未成交保密区间 → LA 看 BA 字段仍脱敏。
    这是经验 5 的核心:mask 条件用 status != confirmed,不是只在 pending 那一刻。
    """
    out = _format(_make_doc("rejected"), viewer_id=LA_ID)
    assert out["ba_deal_price_yuan"] is None
    assert out["ba_deal_date"] is None


def test_ba_still_masked_when_cancelled():
    """cancelled 同样属保密区间 → BA 看 LA 字段仍脱敏"""
    out = _format(_make_doc("cancelled"), viewer_id=BA_ID)
    assert out["la_deal_price_yuan"] is None


# ── 公开区间:confirmed 后双方互看完整 ────────────────────────

def test_confirmed_la_sees_ba_fields():
    """confirmed 后无保密必要 → LA 看得到 BA 填报"""
    out = _format(_make_doc("confirmed"), viewer_id=LA_ID)
    assert out["ba_deal_price_yuan"] == 1_010_000
    assert out["ba_deal_date"] == "2026-05-06"
    assert out["viewer_role"] == "la"


def test_confirmed_ba_sees_la_fields():
    """confirmed 后 BA 也看得到 LA 填报(双向公开)"""
    out = _format(_make_doc("confirmed"), viewer_id=BA_ID)
    assert out["la_deal_price_yuan"] == 1_000_000
    assert out["la_deal_date"] == "2026-05-05"


# ── 无 viewer:内部调用不脱敏,viewer_role 为 None ─────────────

def test_no_viewer_no_mask():
    """不传 viewer_id(后端内部 / 管理后台)→ 不脱敏,viewer_role None"""
    out = _format(_make_doc("pending_la_confirm"))
    assert out["ba_deal_price_yuan"] == 1_010_000
    assert out["la_deal_price_yuan"] == 1_000_000
    assert out["viewer_role"] is None


def test_third_party_viewer_role_none():
    """第三方 viewer(非 LA 非 BA)→ viewer_role None。
    注:真正的 403 拦截在 get_by_id 层,_format 不该被第三方 viewer_id 直接调到;
    此用例锁定 viewer_role 不会误判成 la/ba。
    """
    out = _format(_make_doc("pending_la_confirm"), viewer_id=THIRD_ID)
    assert out["viewer_role"] is None
