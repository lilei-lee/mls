"""property + property_discrepancies 集合 schema + 索引函数"""
from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field
from pymongo import ASCENDING, DESCENDING

from database import db

properties_collection = db["properties"]
property_discrepancies_collection = db["property_discrepancies"]


# ============ Property Schema ============

class TransactionHistoryEntry(BaseModel):
    deal_price_yuan: int
    deal_date: str
    transaction_id: Optional[str] = None
    source: str = "mls_internal"
    verified: bool = False
    created_at: datetime


class ListingHistoryEntry(BaseModel):
    list_price_wan: int
    listed_at: datetime
    delisted_at: Optional[datetime] = None
    sold: bool = False
    listing_id: Optional[str] = None
    source: str = "mls_internal"


class PropertyStandardAssets(BaseModel):
    floor_plan_url: Optional[str] = None
    real_photos: list[str] = Field(default_factory=list)


class PropertyDoc(BaseModel):
    property_code: str
    city_id: str
    district_id: str
    community_id: str
    building: str
    unit: str
    room_no: str
    authoritative_attrs: dict = Field(default_factory=dict)
    attribute_claims: list[dict] = Field(default_factory=list)
    # V2.2: 新增 claim 字段(与物理 6 字段同流程)
    objective_features: Optional[list[str]] = None
    decoration: Optional[str] = None
    transaction_history: list[TransactionHistoryEntry] = Field(default_factory=list)
    listing_history: list[ListingHistoryEntry] = Field(default_factory=list)
    standard_assets: PropertyStandardAssets = Field(default_factory=PropertyStandardAssets)
    created_at: datetime
    updated_at: datetime


# ============ Discrepancy Schema ============

class HistoricalValueEntry(BaseModel):
    value: Any
    listing_id: str
    listed_at: datetime
    agent_id: str


class DiscrepancyDoc(BaseModel):
    property_id: str
    listing_id: str
    agent_id: str
    field: str
    historical_values: list[HistoricalValueEntry] = Field(default_factory=list)
    new_value: Any
    authoritative_value: Any = None
    status: str = "pending"
    evidence_urls: list[str] = Field(default_factory=list)
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    resolution_note: Optional[str] = None
    created_at: datetime


# ============ 索引初始化 ============

def ensure_property_indexes() -> dict[str, list[str]]:
    # properties
    properties_collection.create_index(
        "property_code", unique=True, name="properties_code_unique"
    )
    properties_collection.create_index(
        [
            ("city_id", ASCENDING), ("district_id", ASCENDING),
            ("community_id", ASCENDING), ("building", ASCENDING),
            ("unit", ASCENDING), ("room_no", ASCENDING),
        ],
        unique=True, name="properties_full_address_unique",
    )
    properties_collection.create_index(
        [("community_id", ASCENDING)], name="properties_community"
    )

    # discrepancies
    property_discrepancies_collection.create_index(
        [("property_id", ASCENDING)], name="discrepancies_property"
    )
    property_discrepancies_collection.create_index(
        [("status", ASCENDING), ("created_at", DESCENDING)], name="discrepancies_status_time"
    )
    property_discrepancies_collection.create_index(
        [("agent_id", ASCENDING)], name="discrepancies_agent"
    )

    return {
        "properties": list(properties_collection.index_information().keys()),
        "discrepancies": list(property_discrepancies_collection.index_information().keys()),
    }
