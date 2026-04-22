"""
MLS 模块五下半段 - 合作奖金结算(交易留痕节点 ⑥)
作者:磊

MVP 范围(G 本轮):
- transaction 变 confirmed 时,listing.bonus_yuan > 0 则自动生成 settlement
- 金额锁定 = BA 提交成交确认时刻的 bonus_yuan(V10 决策)
- 状态机:pending_payment → pending_receipt → settled
- 本轮只做 LA 标记"已付款"的 pending_payment → pending_receipt
- BA 确认收款(带证据上传)等 B 对象存储迁完后补

状态定义:
- pending_payment:待 LA 付款(初始态)
- pending_receipt:待 BA 确认已收(LA 已标记已付)
- settled:已结清(终态,BA 已确认)
- disputed:异议(占位,MVP 不做流程)

技术债登记:
- BA 确认收款 + 证据上传(依赖对象存储)
- 异议流程(依赖争议模块)
- 超期提醒(14 天未付/未确认,依赖推送)
- 奖金历史查询接口(bonus-history)
"""
from datetime import datetime
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import db

settlements_collection = db["settlements"]


# ==================== 数据模型 ====================

class LaMarkPaidBody(BaseModel):
    """LA 标记已付款"""
    note: Optional[str] = Field(None, max_length=200, description="备注(选填)")


# ==================== 索引 ====================

def ensure_settlements_indexes():
    settlements_collection.create_index("transaction_id", unique=True)
    settlements_collection.create_index("listing_id")
    settlements_collection.create_index("la_agent_id")
    settlements_collection.create_index("ba_agent_id")
    settlements_collection.create_index([("la_agent_id", 1), ("status", 1)])
    settlements_collection.create_index([("ba_agent_id", 1), ("status", 1)])


# ==================== 工具 ====================

def _to_oid(s: str, detail: str = "无效的ID") -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail=detail)


# ==================== 业务函数 ====================

def create_settlement_for_transaction(
    transaction_doc: dict,
    bonus_yuan: int,
) -> Optional[ObjectId]:
    """成交 confirmed 时被 transactions.la_confirm_transaction 调用。

    bonus_yuan 由调用方传入(从 listing 当前值取),这里不重新查,
    因为调用方上下文已经持有 listing 和 transaction。
    """
    if bonus_yuan <= 0:
        return None  # 无奖金不生成

    existing = settlements_collection.find_one({
        "transaction_id": transaction_doc["_id"]
    })
    if existing:
        return existing["_id"]  # 幂等:已存在直接返

    now = datetime.now()
    doc = {
        "transaction_id": transaction_doc["_id"],
        "listing_id": transaction_doc["listing_id"],
        "listing_snapshot": transaction_doc.get("listing_snapshot", {}),

        "ba_agent_id": transaction_doc["ba_agent_id"],
        "ba_agent_name": transaction_doc.get("ba_agent_name", ""),
        "la_agent_id": transaction_doc["la_agent_id"],
        "la_agent_name": transaction_doc.get("la_agent_name", ""),

        "bonus_yuan": bonus_yuan,

        # 冗余展示字段
        "deal_price_yuan": transaction_doc.get("la_deal_price_yuan")
                           or transaction_doc.get("ba_deal_price_yuan"),
        "deal_date": transaction_doc.get("la_deal_date")
                     or transaction_doc.get("ba_deal_date"),

        "status": "pending_payment",

        # LA 付款信息
        "la_paid_at": None,
        "la_payment_note": None,

        # BA 收款信息(本轮不填)
        "ba_received_at": None,
        "ba_receipt_note": None,
        "ba_receipt_proof_url": None,  # 预留:等 B 对象存储

        # 异议信息(占位)
        "dispute_raised_by": None,
        "dispute_reason": None,
        "disputed_at": None,

        "settled_at": None,
        "created_at": now,
        "updated_at": now,
    }
    result = settlements_collection.insert_one(doc)
    return result.inserted_id


def la_mark_paid(
    settlement_id: str,
    body: LaMarkPaidBody,
    la_agent_id: ObjectId,
) -> dict:
    """LA 标记我已付款"""
    oid = _to_oid(settlement_id, "无效的结算单ID")
    doc = settlements_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="结算单不存在")
    if doc["la_agent_id"] != la_agent_id:
        raise HTTPException(status_code=403, detail="只有付款方可以操作")
    if doc["status"] != "pending_payment":
        raise HTTPException(
            status_code=400,
            detail=f"当前状态不支持此操作(status={doc['status']})"
        )

    now = datetime.now()
    result = settlements_collection.update_one(
        {"_id": oid, "status": "pending_payment"},  # 乐观锁
        {"$set": {
            "status": "pending_receipt",
            "la_paid_at": now,
            "la_payment_note": (body.note or "").strip() or None,
            "updated_at": now,
        }}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=409, detail="状态已变更,请刷新后重试")

    new_doc = settlements_collection.find_one({"_id": oid})
    return _format(new_doc, la_agent_id)


def get_by_id(settlement_id: str, viewer_id: ObjectId) -> dict:
    oid = _to_oid(settlement_id, "无效的结算单ID")
    doc = settlements_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="结算单不存在")
    if viewer_id not in (doc["ba_agent_id"], doc["la_agent_id"]):
        raise HTTPException(status_code=403, detail="无权查看")
    return _format(doc, viewer_id)


def list_pending_for_me(
    agent_id: ObjectId, skip: int = 0, limit: int = 50
) -> tuple[list, int]:
    """待我处理的结算单。
    - LA 身份:status=pending_payment 的待我付款
    - BA 身份:status=pending_receipt 的待我确认收款(本轮前端先不消费)
    """
    query = {
        "$or": [
            {"la_agent_id": agent_id, "status": "pending_payment"},
            {"ba_agent_id": agent_id, "status": "pending_receipt"},
        ]
    }
    total = settlements_collection.count_documents(query)
    cursor = (
        settlements_collection.find(query)
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    return [_format_lite(doc, agent_id) for doc in cursor], total


def count_pending_for_me(agent_id: ObjectId) -> int:
    """工作台角标:待我操作的奖金单数(LA 待付 + BA 待确认合计)"""
    return settlements_collection.count_documents({
        "$or": [
            {"la_agent_id": agent_id, "status": "pending_payment"},
            {"ba_agent_id": agent_id, "status": "pending_receipt"},
        ]
    })


# ==================== 格式化器 ====================

def _format(doc: dict, viewer_id: Optional[ObjectId] = None) -> dict:
    """详情版(viewer-aware)"""
    is_la = viewer_id is not None and viewer_id == doc.get("la_agent_id")
    is_ba = viewer_id is not None and viewer_id == doc.get("ba_agent_id")

    return {
        "settlement_id": str(doc["_id"]),
        "transaction_id": str(doc["transaction_id"]),
        "listing_id": str(doc["listing_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),

        "ba_agent_name": doc.get("ba_agent_name", ""),
        "la_agent_name": doc.get("la_agent_name", ""),

        "bonus_yuan": doc.get("bonus_yuan", 0),
        "deal_price_yuan": doc.get("deal_price_yuan"),
        "deal_date": doc["deal_date"].strftime("%Y-%m-%d")
        if doc.get("deal_date") else None,

        "status": doc["status"],

        "la_paid_at": doc["la_paid_at"].isoformat() if doc.get("la_paid_at") else None,
        "la_payment_note": doc.get("la_payment_note"),

        "ba_received_at": doc["ba_received_at"].isoformat()
        if doc.get("ba_received_at") else None,
        "ba_receipt_note": doc.get("ba_receipt_note"),

        "settled_at": doc["settled_at"].isoformat() if doc.get("settled_at") else None,
        "created_at": doc["created_at"].isoformat(),

        "viewer_role": "la" if is_la else ("ba" if is_ba else None),
    }


def _format_lite(doc: dict, viewer_id: ObjectId) -> dict:
    """列表轻量版"""
    is_la = viewer_id == doc.get("la_agent_id")
    return {
        "settlement_id": str(doc["_id"]),
        "transaction_id": str(doc["transaction_id"]),
        "listing_snapshot": doc.get("listing_snapshot", {}),
        "counterpart_name": doc.get("ba_agent_name", "") if is_la
                            else doc.get("la_agent_name", ""),
        "bonus_yuan": doc.get("bonus_yuan", 0),
        "deal_price_yuan": doc.get("deal_price_yuan"),
        "status": doc["status"],
        "viewer_role": "la" if is_la else "ba",
        "created_at": doc["created_at"].isoformat(),
    }