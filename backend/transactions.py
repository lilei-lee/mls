"""
MLS 模块五 - 成交确认(交易留痕节点 ⑤)
作者:磊

MVP 范围(与 V10 业务设计一致):
- BA 发起,LA 独立填价确认
- 前置门槛:listing 必须是 deposit_paid 或 transaction_ongoing
- 必须有一条 confirmed 的 showing,且属于发起人(BA)
- 价格分毫不差,不一致 → rejected(不是 disputed,和 V10 一致)
- LA 可手动驳回(带理由),BA 可在 LA 操作前撤回
- confirmed 后自动把 listing 置为 sold + 冻结交易记录

V7.1 更新:_format 加 viewer 视角隔离 —— LA 在 pending_la_confirm 下
看不到 BA 填的价/日期/备注,双方独立填价防伪。

技术债登记(后续补齐):
- LA 催促 + 14 天回退发起 (模块七做完后)
- 驳回超 2 次冻结 (模块七做完后)
- 30 天修正窗口 (独立流程)
- 自促成交 LA=BA 分支
- 未关联 BA 通知 (依赖推送模块)
- 后台代确认 (依赖管理后台)
- 成交价修正 / 争议举报 (独立模块)
"""
from datetime import datetime
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import db
from settlements import create_settlement_for_transaction

transactions_collection = db["transactions"]
showings_collection = db["showings"]
listings_collection = db["listings"]


# ==================== 数据模型 ====================

class InitiateTransactionBody(BaseModel):
    """BA 发起成交确认"""
    showing_id: str = Field(..., description="关联的已确认带看记录")
    deal_price_yuan: int = Field(..., gt=0, le=500_000_000,
                                  description="成交价(元,整数,分毫不差)")
    deal_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$",
                           description="成交日期 YYYY-MM-DD")
    notes: Optional[str] = Field(None, max_length=200, description="补充备注")


class LaConfirmTransactionBody(BaseModel):
    """LA 独立填报"""
    deal_price_yuan: int = Field(..., gt=0, le=500_000_000)
    deal_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")


class LaRejectTransactionBody(BaseModel):
    """LA 手动驳回"""
    reason: str = Field(..., min_length=1, max_length=100)


class UpdateMyTransactionBody(BaseModel):
    """发起方(BA)修改自己的填报"""
    deal_price_yuan: Optional[int] = Field(None, gt=0, le=500_000_000)
    deal_date: Optional[str] = Field(None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    notes: Optional[str] = Field(None, max_length=200)


class LaUpdateMySubmissionBody(BaseModel):
    """LA 在 rejected 状态下修改自己的填报"""
    la_deal_price_yuan: int = Field(..., gt=0, le=500_000_000)
    la_deal_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")


class CancelTransactionBody(BaseModel):
    """撤回"""
    reason: Optional[str] = Field(None, max_length=100)


# ==================== 索引 ====================

def ensure_transactions_indexes():
    transactions_collection.create_index("showing_id")
    transactions_collection.create_index("listing_id")
    transactions_collection.create_index("ba_agent_id")
    transactions_collection.create_index("la_agent_id")
    transactions_collection.create_index([("la_agent_id", 1), ("status", 1)])


# ==================== 工具 ====================

def _to_oid(s: str, detail: str = "无效的ID") -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail=detail)


def _parse_date(s: str) -> datetime:
    """把 YYYY-MM-DD 字符串转成 datetime(00:00:00 tz-naive)"""
    try:
        return datetime.strptime(s, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="日期格式错误,需 YYYY-MM-DD")


# ==================== 辞典 sink ====================

def sink_transaction_to_dict(tx: dict, listing: dict | None) -> str:
    """V2.1 #15: 成交 confirmed 时沉淀到辞典 transaction_history。

    返回 'synced' / 'no_property_code' / 'queued'。
    异常不抛出,不阻断主流程。
    """
    property_code = listing.get("property_code") if listing else None
    if not property_code:
        print(f"[sink] WARNING: no property_code — tx={tx.get('_id')} listing={tx.get('listing_id')}")
        return "no_property_code"

    from dictionary_client import DictionaryClient, DictionaryUnavailableError, DictionaryForbiddenError

    try:
        DictionaryClient().sink_transaction(
            code=property_code,
            deal_price_yuan=tx["la_deal_price_yuan"],
            deal_date=tx["la_deal_date"].strftime("%Y-%m-%d")
            if hasattr(tx["la_deal_date"], "strftime") else str(tx["la_deal_date"]),
            source="mls_internal",
            transaction_id=str(tx["_id"]),
            verified=True,
        )
        return "synced"
    except DictionaryUnavailableError as e:
        db["pending_dict_sinks"].insert_one({
            "transaction_id": tx["_id"],
            "property_code": property_code,
            "deal_price_yuan": tx["la_deal_price_yuan"],
            "deal_date": tx["la_deal_date"].strftime("%Y-%m-%d")
            if hasattr(tx["la_deal_date"], "strftime") else str(tx["la_deal_date"]),
            "ba_agent_id": tx.get("ba_agent_id"),
            "la_agent_id": tx.get("la_agent_id"),
            "retry_count": 0,
            "last_error": str(e),
            "created_at": datetime.now(),
        })
        print(f"[sink] ALERT: degraded to retry queue — tx={tx['_id']} error={e}")
        return "queued"
    except (DictionaryForbiddenError, ValueError) as e:
        db["pending_dict_sinks"].insert_one({
            "transaction_id": tx["_id"],
            "property_code": property_code,
            "deal_price_yuan": tx["la_deal_price_yuan"],
            "deal_date": tx["la_deal_date"].strftime("%Y-%m-%d")
            if hasattr(tx["la_deal_date"], "strftime") else str(tx["la_deal_date"]),
            "ba_agent_id": tx.get("ba_agent_id"),
            "la_agent_id": tx.get("la_agent_id"),
            "retry_count": 0,
            "last_error": str(e),
            "created_at": datetime.now(),
        })
        print(f"[sink] ALERT: non-retryable failure — tx={tx['_id']} error={e}")
        return "queued"


# ==================== 业务函数 ====================

def initiate_transaction(body: InitiateTransactionBody, ba_agent: dict) -> dict:
    """BA 发起成交确认"""
    # 1. 校验 showing
    showing_oid = _to_oid(body.showing_id, "无效的带看ID")
    showing = showings_collection.find_one({"_id": showing_oid})
    if not showing:
        raise HTTPException(status_code=404, detail="带看记录不存在")
    if showing["ba_agent_id"] != ba_agent["_id"]:
        raise HTTPException(status_code=403, detail="只能基于自己的带看记录发起成交确认")
    if showing["status"] != "confirmed":
        raise HTTPException(status_code=400,
                            detail="该带看记录未被 LA 确认,不能发起成交确认")

    # 2. 校验 listing 状态(前置门槛)
    listing = listings_collection.find_one({"_id": showing["listing_id"]})
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")
    # V2.1 #14: sold 专属文案,#15 楼盘辞典实施时改 property 维度
    if listing["status"] == "sold":
        raise HTTPException(status_code=400, detail="该房源已成交,无法发起新协作")
    if listing["status"] not in ("deposit_paid", "transaction_ongoing"):
        raise HTTPException(
            status_code=400,
            detail="房源尚未进入交易阶段,请先联系 Listing Agent 标记「定金已付」或「成交进行中」后再发起"
        )

    # 3. 日期校验
    deal_dt = _parse_date(body.deal_date)
    if deal_dt > datetime.now():
        raise HTTPException(status_code=400, detail="成交日期不能晚于今天")
    # 日期粒度比较:把带看时间截到当天 00:00,避免"同天带看同天成交"被拦
    # (deal_dt 本来就是 _parse_date 出的 00:00,showing_time 是带时刻的)
    showing_day = showing["showing_time"].replace(
        hour=0, minute=0, second=0, microsecond=0)
    if deal_dt < showing_day:
        raise HTTPException(status_code=400, detail="成交日期不能早于带看日期")

    # 4. 同一房源"单一待确认"控制
    existing = transactions_collection.find_one({
        "listing_id": showing["listing_id"],
        "status": {"$in": ["pending_la_confirm", "confirmed"]},
    })
    if existing:
        if existing["status"] == "confirmed":
            raise HTTPException(status_code=400, detail="该房源已完成成交确认")
        # 同 showing 的发起方自己重发:返回友好提示
        if existing["ba_agent_id"] == ba_agent["_id"]:
            raise HTTPException(status_code=400,
                                detail="您已发起过成交确认,请到详情页查看或撤回重发")
        raise HTTPException(status_code=400,
                            detail="该房源已有待确认的成交记录,请等待处理完成后再试")

    # 5. 组装文档
    now = datetime.now()
    doc = {
        "showing_id": showing_oid,
        "showing_request_id": showing["showing_request_id"],
        "listing_id": showing["listing_id"],
        "listing_snapshot": {
            **showing.get("listing_snapshot", {}),
            "property_code": listing.get("property_code"),
        },
        "ba_agent_id": showing["ba_agent_id"],
        "ba_agent_name": showing["ba_agent_name"],
        "ba_agent_phone": showing.get("ba_agent_phone", ""),
        "la_agent_id": showing["la_agent_id"],
        "la_agent_name": showing["la_agent_name"],

        # 奖金快照(V10 决策:金额锁定时点=BA 提交时)
        # 读 listing 当前 bonus_yuan 存进来,la_confirm 生成 settlement 时优先读这个
        "bonus_yuan_snapshot": int(listing.get("bonus_yuan", 0) or 0),

        # BA 填报(发起时写)
        "ba_deal_price_yuan": body.deal_price_yuan,
        "ba_deal_date": deal_dt,
        "ba_notes": (body.notes or "").strip(),
        "ba_submitted_at": now,
        "ba_updated_at": now,

        # LA 填报(还没填)
        "la_deal_price_yuan": None,
        "la_deal_date": None,
        "la_submitted_at": None,

        # 状态
        "status": "pending_la_confirm",
        # reject_reason: LA 手动驳回理由
        # reject_kind: "manual"(LA 主动) | "price_mismatch"(系统自动)
        "reject_reason": None,
        "reject_kind": None,
        "cancel_reason": None,

        "confirmed_at": None,
        "rejected_at": None,
        "cancelled_at": None,
        "created_at": now,
        "updated_at": now,
    }
    result = transactions_collection.insert_one(doc)
    return {"transaction_id": str(result.inserted_id)}


def _compare_and_finalize(
    oid: ObjectId,
    doc: dict,
    ba_price_yuan: int,
    ba_date,
    la_price_yuan: int,
    la_date,
    expected_status: str,
    extra_set: dict,
    now: datetime,
) -> str:
    """比对 BA/LA 填报→终态 + 副作用。返回 'confirmed' 或 'rejected'。

    expected_status: 乐观锁条件,由 caller 显式传("pending_la_confirm" 或 "rejected")。
    extra_set: caller 侧已填的字段(LA 或 BA 的填报值),合并进原子 update。
    不负责 _format——caller 自己调。

    反作弊比对字段清单(当前:价格 + 日期):
    - ba_price_yuan / la_price_yuan: 成交价格(元,整数)
    - ba_date / la_date: 成交日期(date 对象,天级精度零容差)
    future 增加比对字段必须同步更新:此清单 + reject_reason 三分支表

    reject_reason 三分支表:
    | 价格一致 | 日期一致 | 结果 |
    |---------|---------|------|
    | ✅      | ✅      | confirmed(成交生效,房源→sold) |
    | ❌      | ✅      | rejected:"成交价格不一致,请双方核实" |
    | ✅      | ❌      | rejected:"成交时间不一致,请双方核实" |
    | ❌      | ❌      | rejected:"成交价格及成交时间均不一致,请双方核实" |

    字段缺失防御:任一比对字段为 None,helper 直接 raise ValueError
    (deny by default,不依赖 caller 护栏——future 加 caller 必读此清单)
    """
    # 反作弊基石防御:helper 不假设 caller 已校验,缺字段直接拒
    # future 加 caller 必须读上方"反作弊比对字段清单",不可绕过此 guard
    if ba_date is None or la_date is None:
        raise ValueError("反作弊比对失败:成交日期缺失")
    if ba_price_yuan is None or la_price_yuan is None:
        raise ValueError("反作弊比对失败:成交价格缺失")

    price_match = (la_price_yuan == ba_price_yuan)
    # 归一化到 date 对象做天级比对,零容差(去掉时分秒防跨天边界)
    date_match = (
        la_date.date() == ba_date.date()
    ) if la_date and ba_date else (la_date == ba_date)

    set_fields = dict(extra_set)

    if price_match and date_match:
        set_fields.update({
            "status": "confirmed",
            "confirmed_at": now,
            "updated_at": now,
        })
        if expected_status == "rejected":
            set_fields.update({
                "reject_kind": None,
                "reject_reason": None,
                "rejected_at": None,
            })

        result = transactions_collection.update_one(
            {"_id": oid, "status": expected_status},
            {"$set": set_fields},
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

        listings_collection.update_one(
            {"_id": doc["listing_id"]},
            {"$set": {
                "status": "sold",
                "sold_at": now,
                "sold_price_yuan": la_price_yuan,
                "sold_date": la_date,
                "updated_at": now,
            }},
        )

        # V2.1 #15: 成交事实沉淀到辞典(异常不阻断)
        listing_for_sink = listings_collection.find_one({"_id": doc["listing_id"]})
        sink_tx = {**doc, **set_fields}  # merged: la_deal_price_yuan/date 已写入
        sink_transaction_to_dict(sink_tx, listing_for_sink)

        bonus_yuan = doc.get("bonus_yuan_snapshot")
        if bonus_yuan is None:
            listing_doc = listing_for_sink  # reuse
            bonus_yuan = int(listing_doc.get("bonus_yuan", 0) or 0) if listing_doc else 0
        else:
            bonus_yuan = int(bonus_yuan)

        if bonus_yuan > 0:
            latest_tx = transactions_collection.find_one({"_id": oid})
            if latest_tx:
                create_settlement_for_transaction(latest_tx, bonus_yuan)

        return "confirmed"
    else:
        # 三分支 reject_reason:区分价格不一致 / 时间不一致 / 双不一致
        if not price_match and date_match:
            reject_reason = "成交价格不一致,请双方核实"
        elif price_match and not date_match:
            reject_reason = "成交时间不一致,请双方核实"
        else:
            reject_reason = "成交价格及成交时间均不一致,请双方核实"

        set_fields.update({
            "status": "rejected",
            "reject_kind": "price_mismatch",
            "reject_reason": reject_reason,
            "rejected_at": now,
            "updated_at": now,
        })

        result = transactions_collection.update_one(
            {"_id": oid, "status": expected_status},
            {"$set": set_fields},
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

        return "rejected"


def la_confirm_transaction(
    transaction_id: str,
    body: LaConfirmTransactionBody,
    la_agent_id: ObjectId,
) -> dict:
    """LA 独立填报 + 自动比对"""
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if doc["la_agent_id"] != la_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以确认")
    if doc["status"] != "pending_la_confirm":
        raise HTTPException(status_code=400,
                            detail=f"当前状态不支持确认(status={doc['status']})")

    deal_dt = _parse_date(body.deal_date)
    now = datetime.now()

    _compare_and_finalize(
        oid=oid,
        doc=doc,
        ba_price_yuan=doc["ba_deal_price_yuan"],
        ba_date=doc["ba_deal_date"],
        la_price_yuan=body.deal_price_yuan,
        la_date=deal_dt,
        expected_status="pending_la_confirm",
        extra_set={
            "la_deal_price_yuan": body.deal_price_yuan,
            "la_deal_date": deal_dt,
            "la_submitted_at": now,
        },
        now=now,
    )

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, la_agent_id)


def proxy_confirm_transaction(transaction_id: str, la_price_yuan: int, la_date_str: str, reason: str) -> dict:
    """后台代确认成交(模块六 §5.3 / 模块五 §3.4b)。反作弊护栏(极重要):

    - **前置**:仅当房源归属人(LA)被暂停/踢出(status ∈ suspended/banned)导致 pending_la_confirm
      卡住时才允许。LA 仍 active → 拒绝(必须本人独立填)。
    - **B 模型(独立填+比对照旧)**:admin 从核实的真实成交合同独立录入 LA 侧 price/date,
      走完全相同的 _compare_and_finalize ——分毫不差才 confirmed,不一致照样 rejected。
      admin 不是"批准 BA 的数字",是"替卡住的 LA 独立填真实值"。比对机制一点不削弱。
    - 调用方(后台路由)的表单**不得回显 BA 已提交值**,防止照抄(那会退化成按对方价成交=套利)。
    - 重留痕:proxy_by/proxy_reason/proxy_at 落库 + 后台 audit_log。
    """
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if doc["status"] != "pending_la_confirm":
        raise HTTPException(status_code=400,
                            detail=f"当前状态不支持代确认(status={doc['status']})")
    la_agent = db["agents"].find_one({"_id": doc["la_agent_id"]})
    if not la_agent or la_agent.get("status") not in ("suspended", "banned"):
        raise HTTPException(
            status_code=400,
            detail="仅当房源归属人(LA)被暂停/踢出导致卡住时才可代确认;LA 正常时必须本人填报",
        )

    deal_dt = _parse_date(la_date_str)
    now = datetime.now()
    _compare_and_finalize(
        oid=oid,
        doc=doc,
        ba_price_yuan=doc["ba_deal_price_yuan"],
        ba_date=doc["ba_deal_date"],
        la_price_yuan=la_price_yuan,
        la_date=deal_dt,
        expected_status="pending_la_confirm",
        extra_set={
            "la_deal_price_yuan": la_price_yuan,
            "la_deal_date": deal_dt,
            "la_submitted_at": now,
            "proxy_confirmed": True,
            "proxy_by": "admin",
            "proxy_reason": (reason or "").strip(),
            "proxy_at": now,
        },
        now=now,
    )
    new_doc = transactions_collection.find_one({"_id": oid})
    return {"status": new_doc["status"], "transaction_id": str(oid)}


def la_reject_transaction(
    transaction_id: str,
    body: LaRejectTransactionBody,
    la_agent_id: ObjectId,
) -> dict:
    """LA 手动驳回(非价格不一致的情况,比如根本没成交过)"""
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if doc["la_agent_id"] != la_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以驳回")
    if doc["status"] != "pending_la_confirm":
        raise HTTPException(status_code=400,
                            detail=f"当前状态不支持驳回(status={doc['status']})")

    reason = body.reason.strip()
    if not reason:
        raise HTTPException(status_code=400, detail="驳回理由不能为空")

    now = datetime.now()
    result = transactions_collection.update_one(
        {"_id": oid, "status": "pending_la_confirm"},
        {"$set": {
            "status": "rejected",
            "reject_kind": "manual",
            "reject_reason": reason,
            "rejected_at": now,
            "updated_at": now,
        }}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, la_agent_id)


def update_my_transaction(
    transaction_id: str,
    body: UpdateMyTransactionBody,
    ba_agent_id: ObjectId,
) -> dict:
    """BA 修改自己的填报(仅 rejected 状态允许,用于核对后重新提交)"""
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if doc["ba_agent_id"] != ba_agent_id:
        raise HTTPException(status_code=403, detail="只有发起人可以修改")
    if doc["status"] != "rejected":
        raise HTTPException(
            status_code=400,
            detail=f"只有被驳回的成交可以修改重提(当前:{doc['status']})"
        )
    if doc.get("reject_kind") == "manual":
        raise HTTPException(
            status_code=400,
            detail="该成交确认被 LA 手动驳回,请联系 LA 沟通后重新发起,而非修改重提",
        )

    # 至少改一个字段
    has_any = any(v is not None for v in [
        body.deal_price_yuan, body.deal_date, body.notes,
    ])
    if not has_any:
        raise HTTPException(status_code=400, detail="未提供任何修改字段")

    now = datetime.now()
    extra_set = {"ba_updated_at": now}

    if body.deal_price_yuan is not None:
        extra_set["ba_deal_price_yuan"] = body.deal_price_yuan
    if body.deal_date is not None:
        deal_dt = _parse_date(body.deal_date)
        if deal_dt > datetime.now():
            raise HTTPException(status_code=400, detail="成交日期不能晚于今天")
        extra_set["ba_deal_date"] = deal_dt
    if body.notes is not None:
        extra_set["ba_notes"] = body.notes.strip()

    # BA 新值 vs LA 已填值比对(对称于 LA 侧 _compare_and_finalize)
    # 注:doc["la_deal_price_yuan"]/["la_deal_date"] 仅用于内部比对,
    # _format(viewer_id=ba_agent_id) 返回时仍对 BA 脱敏 LA 字段
    effective_ba_price = extra_set.get("ba_deal_price_yuan", doc["ba_deal_price_yuan"])
    effective_ba_date = extra_set.get("ba_deal_date", doc["ba_deal_date"])

    _compare_and_finalize(
        oid=oid,
        doc=doc,
        ba_price_yuan=effective_ba_price,
        ba_date=effective_ba_date,
        la_price_yuan=doc["la_deal_price_yuan"],
        la_date=doc["la_deal_date"],
        expected_status="rejected",
        extra_set=extra_set,
        now=now,
    )

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, ba_agent_id)


def update_my_submission_la(
    transaction_id: str,
    body: LaUpdateMySubmissionBody,
    la_agent_id: ObjectId,
) -> dict:
    """LA 修改自己的填报(rejected 后重填,复用比对逻辑)"""
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if doc["la_agent_id"] != la_agent_id:
        raise HTTPException(status_code=403, detail="只有房源归属人可以修改")
    if doc["status"] != "rejected":
        raise HTTPException(
            status_code=400,
            detail=f"只有被驳回的成交可以修改(当前:{doc['status']})"
        )
    if doc.get("reject_kind") == "manual":
        raise HTTPException(
            status_code=400,
            detail="该成交已被您手动驳回,如需恢复请联系 BA 重新发起",
        )

    deal_dt = _parse_date(body.la_deal_date)
    now = datetime.now()

    _compare_and_finalize(
        oid=oid,
        doc=doc,
        ba_price_yuan=doc["ba_deal_price_yuan"],
        ba_date=doc["ba_deal_date"],
        la_price_yuan=body.la_deal_price_yuan,
        la_date=deal_dt,
        expected_status="rejected",
        extra_set={
            "la_deal_price_yuan": body.la_deal_price_yuan,
            "la_deal_date": deal_dt,
            "la_submitted_at": now,
        },
        now=now,
    )

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, la_agent_id)


def cancel_transaction(
    transaction_id: str,
    body: CancelTransactionBody,
    ba_agent_id: ObjectId,
) -> dict:
    """BA 撤回(仅 pending_la_confirm 状态,LA 未操作前)"""
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if doc["ba_agent_id"] != ba_agent_id:
        raise HTTPException(status_code=403, detail="只有发起人可以撤回")
    if doc["status"] != "pending_la_confirm":
        raise HTTPException(
            status_code=400,
            detail=f"LA 已操作过,无法撤回(当前:{doc['status']})"
        )

    now = datetime.now()
    result = transactions_collection.update_one(
        {"_id": oid, "status": "pending_la_confirm"},
        {"$set": {
            "status": "cancelled",
            "cancel_reason": (body.reason or "").strip() or None,
            "cancelled_at": now,
            "updated_at": now,
        }}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, ba_agent_id)


def get_by_id(transaction_id: str, viewer_id: ObjectId) -> dict:
    oid = _to_oid(transaction_id, "无效的成交ID")
    doc = transactions_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="成交记录不存在")
    if viewer_id not in (doc["ba_agent_id"], doc["la_agent_id"]):
        raise HTTPException(status_code=403, detail="无权查看")
    return _format(doc, viewer_id)


def get_by_showing(showing_id: str, viewer_id: ObjectId) -> Optional[dict]:
    """按带看 ID 查最新的成交记录(可能 None)"""
    showing_oid = _to_oid(showing_id, "无效的带看ID")
    showing = showings_collection.find_one({"_id": showing_oid})
    if not showing:
        raise HTTPException(status_code=404, detail="带看记录不存在")
    if viewer_id not in (showing["ba_agent_id"], showing["la_agent_id"]):
        raise HTTPException(status_code=403, detail="无权查看")

    doc = transactions_collection.find_one(
        {"showing_id": showing_oid},
        sort=[("created_at", -1)],
    )
    if not doc:
        return None
    return _format(doc, viewer_id)


def list_pending_for_la(
    la_agent_id: ObjectId, skip: int = 0, limit: int = 50
) -> tuple[list, int]:
    """LA 视角:待我确认的成交"""
    query = {"la_agent_id": la_agent_id, "status": "pending_la_confirm"}
    total = transactions_collection.count_documents(query)
    cursor = (
        transactions_collection.find(query)
        .sort("ba_submitted_at", -1)
        .skip(skip)
        .limit(limit)
    )
    return [_format_lite(doc) for doc in cursor], total


def count_pending_for_la(la_agent_id: ObjectId) -> int:
    return transactions_collection.count_documents({
        "la_agent_id": la_agent_id,
        "status": "pending_la_confirm",
    })


# ═══ Day 37: 公共计数函数(单一数据源) ═══

def _count_la_pending_transactions(la_id) -> int:
    """公共:LA 待确认成交数"""
    oid = _to_oid(str(la_id), "")
    return transactions_collection.count_documents({"la_agent_id": oid, "status": "pending_la_confirm"})


def _count_ba_waiting_transactions(ba_id) -> int:
    """公共:BA 等待 LA 确认的成交数"""
    oid = _to_oid(str(ba_id), "")
    return transactions_collection.count_documents({"ba_agent_id": oid, "status": "pending_la_confirm"})


def has_active_transaction(listing_id: ObjectId) -> bool:
    """listing 是否有"活跃中"的 transaction(pending_la_confirm)
    用于 listing 回退状态时的保护检查
    """
    return transactions_collection.count_documents({
        "listing_id": listing_id,
        "status": "pending_la_confirm",
    }) > 0


# ==================== 格式化器 ====================

def _format(doc: dict, viewer_id: Optional[ObjectId] = None) -> dict:
    """详情版(viewer-aware)。

    viewer_id 用于视角隔离 —— V10 防伪基石:LA 在 pending_la_confirm 状态下
    不能看到 BA 填的价格 / 日期 / 备注,双方独立填价后系统自动比对。
    不传 viewer_id 时不做脱敏(供后端内部调用 / 管理后台使用)。
    """
    is_la = viewer_id is not None and viewer_id == doc.get("la_agent_id")
    is_ba = viewer_id is not None and viewer_id == doc.get("ba_agent_id")
    # 防伪基石:未 confirmed 之前,双方互相隐藏对方填报数据
    # 比价成功(status=confirmed)后才公开,因为已成交无保密必要
    not_confirmed = doc.get("status") != "confirmed"
    mask_ba = is_la and not_confirmed
    mask_la = is_ba and not_confirmed

    return {
        "transaction_id": str(doc["_id"]),
        "showing_id": str(doc["showing_id"]),
        "showing_request_id": str(doc.get("showing_request_id")) if doc.get("showing_request_id") else None,
        "listing_id": str(doc["listing_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),

        "ba_agent_name": doc.get("ba_agent_name", ""),
        "la_agent_name": doc.get("la_agent_name", ""),

        # BA 填报(mask_ba 命中时脱敏)
        "ba_deal_price_yuan": None if mask_ba else doc.get("ba_deal_price_yuan"),
        "ba_deal_date": None if mask_ba else (
            doc["ba_deal_date"].strftime("%Y-%m-%d") if doc.get("ba_deal_date") else None
        ),
        "ba_notes": "" if mask_ba else doc.get("ba_notes", ""),
        "ba_submitted_at": doc["ba_submitted_at"].isoformat()
        if doc.get("ba_submitted_at") else None,
        "ba_updated_at": doc["ba_updated_at"].isoformat()
        if doc.get("ba_updated_at") else None,
        # 前端用这个字段判断"BA 是否已经提交"(不泄露价格)
        "ba_has_submitted": doc.get("ba_submitted_at") is not None,
        "la_has_submitted": doc.get("la_submitted_at") is not None,
        "la_deal_price_yuan": None if mask_la else doc.get("la_deal_price_yuan"),
        "la_deal_date": None if mask_la else (
            doc["la_deal_date"].strftime("%Y-%m-%d") if doc.get("la_deal_date") else None
        ),
        "la_submitted_at": None if mask_la else (
            doc["la_submitted_at"].isoformat() if doc.get("la_submitted_at") else None
        ),

        "status": doc["status"],
        "reject_kind": doc.get("reject_kind"),
        "reject_reason": doc.get("reject_reason"),
        "cancel_reason": doc.get("cancel_reason"),

        "confirmed_at": doc["confirmed_at"].isoformat() if doc.get("confirmed_at") else None,
        "rejected_at": doc["rejected_at"].isoformat() if doc.get("rejected_at") else None,
        "cancelled_at": doc["cancelled_at"].isoformat() if doc.get("cancelled_at") else None,

        "created_at": doc["created_at"].isoformat(),

        # 视角标识,前端用这个判 BA/LA,不再靠姓名兜底
        "viewer_role": "la" if is_la else ("ba" if is_ba else None),
    }


def _format_lite(doc: dict) -> dict:
    """列表轻量版 —— 专用于 LA 的"待我确认成交"列表。

    场景天然是 LA 视角 + pending_la_confirm,直接不返 BA 填价(V10 防伪)。
    """
    return {
        "transaction_id": str(doc["_id"]),
        "listing_id": str(doc["listing_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),
        "ba_agent_name": doc.get("ba_agent_name", ""),
        # 故意不返 ba_deal_price_yuan / ba_deal_date —— 防伪
        "status": doc["status"],
        "ba_submitted_at": doc["ba_submitted_at"].isoformat()
        if doc.get("ba_submitted_at") else None,
    }