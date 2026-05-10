"""V2.2 #4: GET /communities/{id}/detail + /listings + /deals 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from datetime import datetime
from bson import ObjectId


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "测试LA", "phone": "13800001111"}


def _seed_community(suffix="", district="桥东区"):
    from database import db
    name = f"V24_{suffix}_{str(ObjectId())[-6:]}"
    return db["communities"].insert_one({
        "name": name, "district": district,
        "created_at": datetime.now(),
    }).inserted_id


def _seed_listing(community_id, rooms=3, area_sqm=100, price_wan=80.0, status="on_sale", owner_id=None):
    from database import db
    return db["listings"].insert_one({
        "house_code": f"C24-{str(ObjectId())[-6:]}",
        "community": "V24_测试小区", "community_id": community_id,
        "building": "1", "unit": "1", "room_no": str(ObjectId())[-6:],
        "district": "桥东区", "property_code": f"C24PC{str(ObjectId())[-6:]}",
        "layout": f"{rooms}室1卫", "rooms": rooms,
        "orientation": "南", "price_wan": price_wan,
        "area_sqm": area_sqm, "status": status,
        "owner_agent_id": owner_id or ObjectId(), "owner_agent_name": "LA",
        "owner_agent_phone": "138", "sale_points": [], "public_remarks": "",
        "agent_remarks": "", "showing_instructions": "", "photo_count": 0, "photos": [],
        "bonus_yuan": 0, "cover_thumbnail": None,
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


# ═══════════════════ Tests ═══════════════════

def test_detail_returns_full_structure():
    from database import db
    from communities import get_community_detail
    cid = _seed_community()
    lid = _seed_listing(cid, rooms=3, area_sqm=100, price_wan=80)

    result = get_community_detail(str(cid))
    assert "stats" in result
    assert result["stats"]["active_listings"] >= 1
    assert result["stats"]["monthly_new"] >= 0
    assert "listings_preview" in result
    assert len(result["listings_preview"]) >= 1

    db["listings"].delete_one({"_id": lid})
    db["communities"].delete_one({"_id": cid})


def test_listings_room_filter():
    from database import db
    from communities import get_community_listings
    cid = _seed_community()
    lid2 = _seed_listing(cid, rooms=2)
    lid3 = _seed_listing(cid, rooms=3)

    result = get_community_listings(str(cid), room=2)
    assert result["total"] >= 1
    for item in result["items"]:
        assert item.get("rooms") == 2 or item.get("rooms") is None

    db["listings"].delete_many({"_id": {"$in": [lid2, lid3]}})
    db["communities"].delete_one({"_id": cid})


def test_listings_pagination():
    from database import db
    from communities import get_community_listings
    cid = _seed_community()
    lids = [_seed_listing(cid) for _ in range(3)]

    r1 = get_community_listings(str(cid), page=1, page_size=2)
    assert len(r1["items"]) == 2
    assert r1["has_more"] is True

    r2 = get_community_listings(str(cid), page=2, page_size=2)
    assert len(r2["items"]) >= 1
    assert r2["has_more"] is False

    db["listings"].delete_many({"_id": {"$in": lids}})
    db["communities"].delete_one({"_id": cid})


def test_nonexistent_community_returns_404():
    from communities import get_community_detail
    from fastapi import HTTPException
    fake_id = str(ObjectId())
    with pytest.raises(HTTPException) as exc:
        get_community_detail(fake_id)
    assert exc.value.status_code == 404


def test_deals_returns_empty():
    from communities import get_community_deals
    result = get_community_deals(str(ObjectId()))
    assert result["items"] == []
    assert result["total"] == 0
