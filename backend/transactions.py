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
        "listing_snapshot": showing.get("listing_snapshot", {}),
        "ba_agent_id": showing["ba_agent_id"],
        "ba_agent_name": showing["ba_agent_name"],
        "ba_agent_phone": showing.get("ba_agent_phone", ""),
        "la_agent_id": showing["la_agent_id"],
        "la_agent_name": showing["la_agent_name"],

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

    # 价格 + 日期都要分毫不差
    price_match = (body.deal_price_yuan == doc["ba_deal_price_yuan"])
    date_match = (deal_dt == doc["ba_deal_date"])

    if price_match and date_match:
        # 一致 → confirmed + listing 自动 sold
        result = transactions_collection.update_one(
            {"_id": oid, "status": "pending_la_confirm"},  # 乐观锁
            {"$set": {
                "la_deal_price_yuan": body.deal_price_yuan,
                "la_deal_date": deal_dt,
                "la_submitted_at": now,
                "status": "confirmed",
                "confirmed_at": now,
                "updated_at": now,
            }}
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

        # 副作用 1:listing 自动置 sold
        listings_collection.update_one(
            {"_id": doc["listing_id"]},
            {"$set": {
                "status": "sold",
                "sold_at": now,
                "sold_price_yuan": body.deal_price_yuan,
                "sold_date": deal_dt,
                "updated_at": now,
            }}
        )

        # 副作用 2:节点⑥ - 奖金结算单自动生成(V10 决策)
        # 金额锁定 = BA 提交成交确认时 listing 的 bonus_yuan
        # 但我们没有"BA 提交时刻的快照",只能以当前 listing.bonus_yuan 近似
        # (V10 允许 LA 上下调奖金,但本 MVP 让房源有单一 bonus_yuan 字段,
        #  pending_la_confirm 期间不能修改 —— 该规则在 listings.py 的调价接口里约束,
        #  登技术债:调价拦截尚未实现)
        listing_doc = listings_collection.find_one({"_id": doc["listing_id"]})
        bonus_yuan = int(listing_doc.get("bonus_yuan", 0) or 0) if listing_doc else 0
        if bonus_yuan > 0:
            # 重新取最新 transaction doc 以便快照字段齐全
            latest_tx = transactions_collection.find_one({"_id": oid})
            if latest_tx:
                create_settlement_for_transaction(latest_tx, bonus_yuan)
    else:
        # 不一致 → 系统自动 rejected(price_mismatch)
        msgs = []
        if not price_match:
            msgs.append("成交价不一致")
        if not date_match:
            msgs.append("成交日期不一致")
        reason = ";".join(msgs) + ",请双方核实后由 BA 修改重提"

        result = transactions_collection.update_one(
            {"_id": oid, "status": "pending_la_confirm"},
            {"$set": {
                "la_deal_price_yuan": body.deal_price_yuan,
                "la_deal_date": deal_dt,
                "la_submitted_at": now,
                "status": "rejected",
                "reject_kind": "price_mismatch",
                "reject_reason": reason,
                "rejected_at": now,
                "updated_at": now,
            }}
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, la_agent_id)


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

    # 至少改一个字段
    has_any = any(v is not None for v in [
        body.deal_price_yuan, body.deal_date, body.notes,
    ])
    if not has_any:
        raise HTTPException(status_code=400, detail="未提供任何修改字段")

    update = {}
    if body.deal_price_yuan is not None:
        update["ba_deal_price_yuan"] = body.deal_price_yuan
    if body.deal_date is not None:
        deal_dt = _parse_date(body.deal_date)
        if deal_dt > datetime.now():
            raise HTTPException(status_code=400, detail="成交日期不能晚于今天")
        update["ba_deal_date"] = deal_dt
    if body.notes is not None:
        update["ba_notes"] = body.notes.strip()

    # 重提:状态回到 pending_la_confirm,清掉 LA 旧填报和驳回痕迹
    now = datetime.now()
    update.update({
        "ba_updated_at": now,
        "status": "pending_la_confirm",
        "la_deal_price_yuan": None,
        "la_deal_date": None,
        "la_submitted_at": None,
        "reject_kind": None,
        "reject_reason": None,
        "rejected_at": None,
        "updated_at": now,
    })

    result = transactions_collection.update_one(
        {"_id": oid, "status": "rejected"},
        {"$set": update}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

    new_doc = transactions_collection.find_one({"_id": oid})
    return _format(new_doc, ba_agent_id)


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
    # 防伪触发条件:LA 视角 + 待确认状态
    mask_ba = is_la and doc.get("status") == "pending_la_confirm"

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

        "la_deal_price_yuan": doc.get("la_deal_price_yuan"),
        "la_deal_date": doc["la_deal_date"].strftime("%Y-%m-%d")
        if doc.get("la_deal_date") else None,
        "la_submitted_at": doc["la_submitted_at"].isoformat()
        if doc.get("la_submitted_at") else None,

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