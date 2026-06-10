"""小区路由 -- 拆自 main.py L1041-1095"""
from fastapi import APIRouter, HTTPException, Depends, Query
from auth import get_current_agent
from communities import (
    CreateCommunityBody,
    search_communities, create_community, get_community_by_id,
    get_community_detail, get_community_listings, get_community_deals,
)

communities_router = APIRouter(prefix="/api/v1", tags=["communities"])


@communities_router.get("/communities/search")
def search_communities_api(
    q: str = "",
    district: str | None = None,
    limit: int = 10,
    agent: dict = Depends(get_current_agent),
):
    items = search_communities(q, district, limit)
    return {"success": True, "items": items}


@communities_router.post("/communities")
def create_community_api(
    body: CreateCommunityBody,
    agent: dict = Depends(get_current_agent),
):
    result = create_community(body, agent)
    print(f"\n🏘️  新小区: {body.name} ({body.district}) by {agent['name']}")
    return {"success": True, **result, "message": "小区已添加"}


@communities_router.get("/communities/{community_id}")
def get_community_api(
    community_id: str,
    agent: dict = Depends(get_current_agent),
):
    doc = get_community_by_id(community_id)
    return {"success": True, "data": doc}


@communities_router.get("/communities/{community_id}/detail")
def get_community_detail_api(community_id: str, agent: dict = Depends(get_current_agent)):
    """V2.2 #4: 社区详情(档案+统计+预览)"""
    return {"success": True, "data": get_community_detail(community_id)}


@communities_router.get("/communities/{community_id}/listings")
def get_community_listings_api(
    community_id: str,
    room: int | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    agent: dict = Depends(get_current_agent),
):
    """V2.2 #4: 社区在售房源分页"""
    return {"success": True, "data": get_community_listings(community_id, room=room, page=page, page_size=page_size)}


@communities_router.get("/communities/{community_id}/deals")
def get_community_deals_api(community_id: str, agent: dict = Depends(get_current_agent)):
    """V2.2 #4: 社区成交记录(V3 占位)"""
    return {"success": True, "data": get_community_deals(community_id)}

