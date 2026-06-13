"""房源路由 — 拆自 main.py L515-707"""
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from database import db
from auth import get_current_agent
from services.listings import (
    CreateListingRequest, PostListingRequest, _extract_physical_attrs,
    SyncPhysicalBody, CreateListingResponse, MarkDepositPaidBody,
    MarkTransactionOngoingBody, RollbackStatusBody,
    create_listing, list_my_listings, count_my_listings,
    list_shared_listings, count_shared_listings, get_listing_by_id,
    sync_physical_to_dict, update_listing, offline_listing,
    reactivate_listing, get_showings_summary, get_districts,
    mark_listing_deposit_paid, mark_listing_transaction_ongoing,
    rollback_listing_to_on_sale,
)

listings_router = APIRouter(prefix="/api/v1", tags=["listings"])

# ==================== 模块二:房源管理 ====================

@listings_router.post("/listings", response_model=CreateListingResponse)
def create_listing_api(
    req: PostListingRequest,
    agent: dict = Depends(get_current_agent),
):
    physical_attrs = _extract_physical_attrs(req)
    result = create_listing(req, physical_attrs, agent)
    print(f"\n🏠 新房源录入: {req.community} {req.building}-{req.unit}-{req.room_no} by {agent['name']}")
    return CreateListingResponse(
        success=True,
        listing_id=result["listing_id"],
        house_code=result["house_code"],
        message=f"录入成功!一户一码: {result['house_code']}",
    )


class ListingListResponse(BaseModel):
    success: bool
    total: int
    items: list


@listings_router.get("/listings/mine", response_model=ListingListResponse)
def get_my_listings_api(
    skip: int = 0,
    limit: int = 20,
    agent: dict = Depends(get_current_agent),
):
    items = list_my_listings(agent["_id"], skip=skip, limit=limit)
    total = count_my_listings(agent["_id"])
    return ListingListResponse(success=True, total=total, items=items)


def _parse_csv(val: str | None) -> list[str] | None:
    if not val:
        return None
    items = [v.strip() for v in val.split(",") if v.strip()]
    return items or None


@listings_router.get("/listings/shared", response_model=ListingListResponse)
def get_shared_listings_api(
    skip: int = 0,
    limit: int = 20,
    new_today: bool = False,
    sale_points: str | None = Query(None, description="卖点标签,逗号分隔 AND 语义"),
    objective_features: str | None = Query(None, description="客观特征,逗号分隔 AND 语义"),
    decoration: str | None = Query(None, description="装修(单选枚举)"),
    heating_type: str | None = Query(None, description="供暖(单选枚举)"),
    bld_year_min: int | None = Query(None, description="楼龄下限"),
    bld_year_max: int | None = Query(None, description="楼龄上限"),
    community_id: str | None = Query(None, description="小区ID(MLS侧,按小区过滤在售房源)"),
    orientation: str | None = Query(None, description="朝向(朝东/朝西/朝南/朝北)"),
    house_structure: str | None = Query(None, description="户型结构(平层/复式/Loft/跃层/错层/跃复一体)"),
    sort: str | None = Query(None, description="排序:default/latest/price_asc/price_desc/unit_price_asc/area_desc"),
    agent: dict = Depends(get_current_agent),
):
    items, total = list_shared_listings(
        agent["_id"], skip=skip, limit=limit, new_today=new_today,
        sale_points=_parse_csv(sale_points),
        objective_features=_parse_csv(objective_features),
        decoration=decoration,
        heating_type=heating_type,
        bld_year_min=bld_year_min,
        bld_year_max=bld_year_max,
        community_id=community_id,
        orientation=orientation,
        house_structure=house_structure,
        sort=sort,
    )
    return ListingListResponse(success=True, total=total, items=items)


class UpdateListingRequest(BaseModel):
    # 校验约束与 CreateListingRequest 对齐 — PATCH 路径同样是用户可编辑字段,
    # 不能允许 price_wan 负数 / bonus_yuan 超界 / 备注超长绕过创建时的闸门。
    orientation: str | None = Field(None, max_length=20)
    price_wan: float | None = Field(None, gt=0)
    bonus_yuan: int | None = Field(None, ge=0, le=500_000)
    cover_thumbnail: str | None = None
    photos: list | None = None
    public_remarks: str | None = Field(None, max_length=2000)
    agent_remarks: str | None = Field(None, max_length=1000)
    showing_instructions: str | None = Field(None, max_length=500)
    sale_points: list | None = None  # 内容校验在 update_listing 业务层 validate_sale_points


@listings_router.get("/listings/meta/districts")
def get_districts_api(agent: dict = Depends(get_current_agent)):
    return {"success": True, "districts": get_districts()}


# ⚠️ 具体路径必须注册在 {listing_id} 之前

@listings_router.post("/listings/{listing_id}/mark-deposit-paid")
def mark_deposit_paid_api(
    listing_id: str,
    body: MarkDepositPaidBody,
    agent: dict = Depends(get_current_agent),
):
    """V5:标记定金已付"""
    doc = mark_listing_deposit_paid(listing_id, body, agent["_id"])
    print(f"\n💰 房源标记定金已付: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@listings_router.post("/listings/{listing_id}/mark-transaction-ongoing")
def mark_transaction_ongoing_api(
    listing_id: str,
    body: MarkTransactionOngoingBody,
    agent: dict = Depends(get_current_agent),
):
    """V5:标记成交进行中"""
    doc = mark_listing_transaction_ongoing(listing_id, body, agent["_id"])
    print(f"\n📝 房源标记成交进行中: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@listings_router.post("/listings/{listing_id}/rollback-to-on-sale")
def rollback_to_on_sale_api(
    listing_id: str,
    body: RollbackStatusBody,
    agent: dict = Depends(get_current_agent),
):
    """V5:回退到在售"""
    doc = rollback_listing_to_on_sale(listing_id, body, agent["_id"])
    print(f"\n↩️  房源回退到在售: {doc['community']} by {agent['name']} ({body.reason})")
    return {"success": True, "data": doc}


@listings_router.post("/listings/{listing_id}/reactivate")
def reactivate_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = reactivate_listing(listing_id, agent["_id"])
    print(f"\n♻️  房源重新上架: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@listings_router.post("/listings/{listing_id}/sync-physical")
def sync_listing_physical_api(
    listing_id: str,
    body: SyncPhysicalBody = SyncPhysicalBody(),
    agent: dict = Depends(get_current_agent),
):
    return sync_physical_to_dict(listing_id, body, agent["_id"])


@listings_router.get("/listings/{listing_id}/showings-summary")
def get_showings_summary_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    """V2.2 #3: LA 查看自己房源的所有带看记录"""
    return {"success": True, "items": get_showings_summary(listing_id, agent["_id"])}


@listings_router.get("/listings/{listing_id}")
def get_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_listing_by_id(listing_id, viewer_id=agent["_id"])
    if not doc:
        raise HTTPException(status_code=404, detail="房源不存在")
    return {"success": True, "data": doc}


@listings_router.patch("/listings/{listing_id}")
def update_listing_api(
    listing_id: str,
    req: UpdateListingRequest,
    agent: dict = Depends(get_current_agent),
):
    update_fields = req.model_dump(exclude_unset=True)
    doc = update_listing(listing_id, update_fields, agent["_id"])
    print(f"\n🏠 房源更新: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}


@listings_router.delete("/listings/{listing_id}")
def offline_listing_api(
    listing_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = offline_listing(listing_id, agent["_id"])
    print(f"\n🚫 房源下架: {doc['community']} by {agent['name']}")
    return {"success": True, "data": doc}
