"""
MLS 模块三补强 - 小区库
作者:磊

MVP 范围:
- 搜索(前缀/包含匹配)
- 新增(name + district 全局唯一)
- 查单个

业务规则:
- (name, district) 唯一 — 同名不同区算两个小区(如"阳光花园"可能桥东/桥西各一个)
- MVP 不做小区合并(管理后台职责)
- 不回填旧房源
"""
import re
from datetime import datetime
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field

from database import db

communities_collection = db["communities"]


# ==================== 数据模型 ====================

class CreateCommunityBody(BaseModel):
    name: str = Field(..., min_length=1, max_length=50, description="小区标准名")
    district: str = Field(..., min_length=1, max_length=20, description="所属行政区")
    built_year: Optional[int] = Field(None, ge=1900, le=2100, description="建成年代")
    building_count: Optional[int] = Field(None, ge=1, le=1000, description="楼栋数")


# ==================== 索引 ====================

def ensure_communities_indexes():
    communities_collection.create_index("name")
    # 复合唯一索引:同一个行政区内同名只能一个
    communities_collection.create_index(
        [("name", 1), ("district", 1)],
        unique=True,
    )


# ==================== 业务函数 ====================

def _to_oid(s: str, detail: str = "无效的ID") -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail=detail)


def search_communities(
    query: str,
    district: Optional[str] = None,
    limit: int = 10,
) -> list:
    """按名称包含匹配搜索小区"""
    q = (query or "").strip()
    if not q:
        return []

    # 转义正则特殊字符,防注入(用户输入 .* 不会导致命中全部)
    pattern = re.escape(q)
    filter_q: dict = {"name": {"$regex": pattern, "$options": "i"}}
    if district:
        filter_q["district"] = district.strip()

    cursor = (
        communities_collection.find(filter_q)
        .sort([("created_at", -1)])
        .limit(max(1, min(limit, 50)))
    )
    return [_format_community(doc) for doc in cursor]


def create_community(body: CreateCommunityBody, agent: dict) -> dict:
    name = body.name.strip()
    district = body.district.strip()

    # 预查:给出更友好的 409 信息(带 community_id,方便前端复用已存在的小区)
    existing = communities_collection.find_one({
        "name": name,
        "district": district,
    })
    if existing:
        raise HTTPException(
            status_code=409,
            detail={
                "message": f"小区「{name}」在{district}已存在",
                "community_id": str(existing["_id"]),
                "name": existing["name"],
                "district": existing["district"],
            },
        )

    now = datetime.now()
    doc = {
        "name": name,
        "district": district,
        "built_year": body.built_year,
        "building_count": body.building_count,
        "created_at": now,
        "created_by_agent_id": agent["_id"],
        "created_by_agent_name": agent["name"],
    }
    try:
        result = communities_collection.insert_one(doc)
    except Exception as e:
        # 兜底:并发场景下唯一索引冲突
        if "duplicate key" in str(e).lower():
            existing = communities_collection.find_one({
                "name": name, "district": district,
            })
            if existing:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "message": f"小区「{name}」在{district}已存在",
                        "community_id": str(existing["_id"]),
                    },
                )
        raise

    return {"community_id": str(result.inserted_id)}


def get_community_by_id(community_id: str) -> dict:
    oid = _to_oid(community_id, "无效的小区ID")
    doc = communities_collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="小区不存在")
    return _format_community(doc)


# ==================== 格式化器 ====================

def _format_community(doc: dict) -> dict:
    return {
        "community_id": str(doc["_id"]),
        "name": doc["name"],
        "district": doc["district"],
        "built_year": doc.get("built_year"),
        "building_count": doc.get("building_count"),
        "created_at": doc["created_at"].isoformat()
        if doc.get("created_at") else None,
    }