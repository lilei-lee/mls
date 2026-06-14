"""争议 / 举报(模块六 §7 + 经纪人端举报)。

经纪人可对一笔成交或某经纪人发起举报;后台仲裁:受理 → 裁决(含处罚) / 驳回。
处罚 ban 时联动踢出目标经纪人(复用 agents.status=banned)。所有仲裁动作由
后台 routers/admin.py 记入 audit_log。
"""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from database import db

DISPUTE_STATUS = ("pending", "accepted", "resolved", "rejected")
DISPUTE_STATUS_LABEL = {
    "pending": "待受理", "accepted": "审理中", "resolved": "已裁决", "rejected": "已驳回",
}
PENALTY_LABEL = {"none": "无处罚", "warn": "警告", "ban": "踢出"}


class FileDisputeBody(BaseModel):
    """经纪人举报入参。"""
    target_type: Literal["transaction", "agent"] = Field(..., description="举报对象类型")
    target_id: str = Field(..., min_length=1, description="对象 ID")
    reason: str = Field(..., min_length=1, max_length=50, description="举报类别")
    description: str = Field(..., min_length=1, max_length=1000, description="争议描述")


def file_dispute(body: FileDisputeBody, reporter: dict) -> dict:
    doc = {
        "reporter_agent_id": reporter["_id"],
        "reporter_name": reporter.get("name", ""),
        "target_type": body.target_type,
        "target_id": body.target_id,
        "reason": body.reason.strip(),
        "description": body.description.strip(),
        "status": "pending",
        "ruling": None,
        "penalty": None,
        "handled_at": None,
        "created_at": datetime.now(),
    }
    res = db["disputes"].insert_one(doc)
    return {"dispute_id": str(res.inserted_id)}


def ensure_disputes_indexes():
    db["disputes"].create_index("status")
    db["disputes"].create_index("reporter_agent_id")
    db["disputes"].create_index([("status", 1), ("created_at", -1)])
