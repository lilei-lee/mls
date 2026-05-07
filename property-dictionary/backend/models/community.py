"""community 集合 schema 定义 + 索引函数"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from pymongo import ASCENDING

from database import db

communities_collection = db["communities"]


# ============ Schema ============

class CommunityFacilities(BaseModel):
    schools: list[str] = Field(default_factory=list)
    transportation: list[str] = Field(default_factory=list)
    commercial: list[str] = Field(default_factory=list)


class CommunityStandardAssets(BaseModel):
    aerial_photo_url: Optional[str] = None
    entrance_photo_url: Optional[str] = None
    main_layouts: list[str] = Field(default_factory=list)


class CommunityDerivedStats(BaseModel):
    avg_price_wan: Optional[float] = None
    transaction_count_30d: Optional[int] = None
    on_sale_count: Optional[int] = None
    last_updated: Optional[datetime] = None


class CommunityDoc(BaseModel):
    community_code: str = Field(..., description="HMAC 哈希,辞典内唯一身份")
    city_id: str
    district_id: str
    name: str
    aliases: list[str] = Field(default_factory=list)
    built_year: Optional[int] = None
    total_buildings: Optional[int] = None
    total_units: Optional[int] = None
    property_type: Optional[str] = None
    developer: Optional[str] = None
    property_management: Optional[str] = None
    facilities: CommunityFacilities = Field(default_factory=CommunityFacilities)
    standard_assets: CommunityStandardAssets = Field(default_factory=CommunityStandardAssets)
    derived_stats: CommunityDerivedStats = Field(default_factory=CommunityDerivedStats)
    authoritative_attrs: dict = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


# ============ 索引初始化 ============

def ensure_community_indexes() -> list[str]:
    communities_collection.create_index(
        "community_code", unique=True, name="communities_code_unique"
    )
    communities_collection.create_index(
        [("city_id", ASCENDING), ("district_id", ASCENDING), ("name", ASCENDING)],
        unique=True, name="communities_city_district_name_unique",
    )
    communities_collection.create_index(
        [("city_id", ASCENDING), ("name", ASCENDING)],
        name="communities_city_name",
    )
    return list(communities_collection.index_information().keys())
