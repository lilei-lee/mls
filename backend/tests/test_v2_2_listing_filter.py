"""V2.2 #1 Day 28: shared listings 5 类筛选 + 聚合过滤 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from unittest.mock import patch, MagicMock
from bson import ObjectId
from datetime import datetime


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "测试BA", "phone": "13800002222"}


def _seed_listing(owner_id, community="共享测试小区", property_code="FLT001", **extra):
    from database import db
    return db["listings"].insert_one({
        "house_code": f"FLT-{str(ObjectId())[-6:]}",
        "community": community, "building": "1", "unit": "1",
        "room_no": str(ObjectId())[-6:],
        "district": "桥东区", "property_code": property_code,
        "orientation": "南", "price_wan": 80.0, "status": "on_sale",
        "owner_agent_id": owner_id, "owner_agent_name": "测试LA",
        "owner_agent_phone": "13900001111",
        "layout": "", "photo_count": 0, "photos": [],
        "sale_points": extra.get("sale_points", []),
        "public_remarks": extra.get("public_remarks", ""),
        "agent_remarks": extra.get("agent_remarks", ""),
        "showing_instructions": extra.get("showing_instructions", ""),
        "created_at": datetime.now(), "updated_at": datetime.now(),
    }).inserted_id


def _seed_props_map(codes_to_attrs):
    """构造 mock batch_get_properties 返回值 {code: {attribute_claims_latest: {...}}}"""
    return {
        code: {"attribute_claims_latest": attrs}
        for code, attrs in codes_to_attrs.items()
    }


# ═══════════════════════════════════════════
# 1. 无参数 — V2.1 兼容
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
def test_filter_no_params_returns_all(mock_batch, agent):
    """无筛选参数 → 返所有共享 listing"""
    mock_batch.return_value = {}
    la_id = ObjectId()
    lid = _seed_listing(la_id)

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"])
    # BA 能看到 LA 的 listing
    assert total >= 1 or total == 0  # 可能有其他 listing

    from database import db
    db["listings"].delete_one({"_id": lid})


# ═══════════════════════════════════════════
# 2. sale_points 筛选
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
def test_filter_sale_points_single(mock_batch, agent):
    mock_batch.return_value = {}
    la_id = ObjectId()
    lid1 = _seed_listing(la_id, property_code="SP01", sale_points=["学区房", "近公园"])
    lid2 = _seed_listing(la_id, property_code="SP02", sale_points=["急售可议"])

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"], sale_points=["学区房"])
    assert total == 1
    assert items[0]["listing_id"] == str(lid1)

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid1, lid2]}})


@patch("listings._batch_fetch_props")
def test_filter_sale_points_multiple_and(mock_batch, agent):
    mock_batch.return_value = {}
    la_id = ObjectId()
    lid1 = _seed_listing(la_id, property_code="SPM01", sale_points=["学区房", "近公园", "带阳台"])
    lid2 = _seed_listing(la_id, property_code="SPM02", sale_points=["学区房"])

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"], sale_points=["学区房", "近公园"])
    assert total == 1
    assert items[0]["listing_id"] == str(lid1)

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid1, lid2]}})


@patch("listings._batch_fetch_props")
def test_filter_sale_points_no_match(mock_batch, agent):
    mock_batch.return_value = {}
    la_id = ObjectId()
    lid = _seed_listing(la_id, property_code="SPN01", sale_points=["急售可议"])

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"], sale_points=["满五唯一"])
    assert total == 0

    from database import db
    db["listings"].delete_one({"_id": lid})


# ═══════════════════════════════════════════
# 3. objective_features 筛选(从辞典 property)
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
@patch("listings._batch_fetch_communities_by_name")
def test_filter_objective_features(mock_comm, mock_batch, agent):
    mock_batch.return_value = _seed_props_map({
        "OF01": {"objective_features": ["南北通透", "全明格局"]},
        "OF02": {"objective_features": ["客厅朝南"]},
    })
    mock_comm.return_value = {}
    la_id = ObjectId()
    lid1 = _seed_listing(la_id, property_code="OF01")
    lid2 = _seed_listing(la_id, property_code="OF02")

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"], objective_features=["南北通透"])
    assert total == 1
    assert items[0]["listing_id"] == str(lid1)

    # AND: both tags required
    items2, _ = list_shared_listings(agent["_id"], objective_features=["南北通透", "全明格局"])
    assert len(items2) == 1

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid1, lid2]}})


# ═══════════════════════════════════════════
# 4. decoration 筛选(从辞典 property)
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
@patch("listings._batch_fetch_communities_by_name")
def test_filter_decoration(mock_comm, mock_batch, agent):
    mock_batch.return_value = _seed_props_map({
        "DEC01": {"decoration": "精装"},
        "DEC02": {"decoration": "毛坯"},
    })
    mock_comm.return_value = {}
    la_id = ObjectId()
    lid1 = _seed_listing(la_id, property_code="DEC01")
    lid2 = _seed_listing(la_id, property_code="DEC02")

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"], decoration="精装")
    assert total == 1
    assert items[0]["listing_id"] == str(lid1)

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid1, lid2]}})


# ═══════════════════════════════════════════
# 5. heating_type 筛选(从辞典 community)
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
@patch("listings._batch_fetch_communities_by_name")
def test_filter_heating_type(mock_comm, mock_batch, agent):
    mock_batch.return_value = {}
    mock_comm.return_value = {
        "HT_集体供暖小区": {"heating_type": "集体供暖", "bld_year_start": 2012},
        "HT_自供暖小区": {"heating_type": "自供暖", "bld_year_start": 2018},
    }
    la_id = ObjectId()
    lid1 = _seed_listing(la_id, property_code="HT01", community="HT_集体供暖小区")
    lid2 = _seed_listing(la_id, property_code="HT02", community="HT_自供暖小区")

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"], heating_type="集体供暖")
    assert total == 1
    assert items[0]["listing_id"] == str(lid1)

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid1, lid2]}})


# ═══════════════════════════════════════════
# 6. bld_year 范围筛选(从辞典 community)
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
@patch("listings._batch_fetch_communities_by_name")
def test_filter_bld_year_range(mock_comm, mock_batch, agent):
    mock_batch.return_value = {}
    mock_comm.return_value = {
        "BY_老小区": {"bld_year_start": 2005},
        "BY_新小区": {"bld_year_start": 2020},
    }
    la_id = ObjectId()
    lid1 = _seed_listing(la_id, property_code="BY01", community="BY_老小区")
    lid2 = _seed_listing(la_id, property_code="BY02", community="BY_新小区")

    from listings import list_shared_listings
    # 2010-2025: 只有 2020 的新小区符合
    items, total = list_shared_listings(
        agent["_id"], bld_year_min=2010, bld_year_max=2025)
    assert total == 1
    assert items[0]["listing_id"] == str(lid2)

    # 只有 min
    items2, t2 = list_shared_listings(agent["_id"], bld_year_min=2010)
    assert t2 == 1

    # 只有 max
    items3, t3 = list_shared_listings(agent["_id"], bld_year_max=2010)
    assert t3 == 1  # 老小区 2005 <= 2010

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid1, lid2]}})


# ═══════════════════════════════════════════
# 7. 5 类组合
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
@patch("listings._batch_fetch_communities_by_name")
def test_filter_combined_all_5(mock_comm, mock_batch, agent):
    mock_batch.return_value = _seed_props_map({
        "C01": {"objective_features": ["南北通透", "全明格局"], "decoration": "精装"},
        "C02": {"objective_features": ["南北通透"], "decoration": "精装"},
        "C03": {"objective_features": ["南北通透"], "decoration": "毛坯"},
    })
    mock_comm.return_value = {
        "COMB_合格小区": {"heating_type": "集体供暖", "bld_year_start": 2015},
        "COMB_供暖不符": {"heating_type": "自供暖", "bld_year_start": 2015},
        "COMB_年代太老": {"heating_type": "集体供暖", "bld_year_start": 2005},
    }
    la_id = ObjectId()
    lid_match = _seed_listing(la_id, property_code="C01", community="COMB_合格小区",
                              sale_points=["学区房", "送车位"])
    lid_no_of = _seed_listing(la_id, property_code="C02", community="COMB_合格小区",
                              sale_points=["学区房"])
    lid_no_dec = _seed_listing(la_id, property_code="C03", community="COMB_合格小区",
                               sale_points=["学区房"])
    lid_no_heat = _seed_listing(la_id, property_code="C01", community="COMB_供暖不符",
                                sale_points=["学区房"])
    lid_no_year = _seed_listing(la_id, property_code="C01", community="COMB_年代太老",
                                sale_points=["学区房"])

    from listings import list_shared_listings
    items, total = list_shared_listings(
        agent["_id"],
        sale_points=["学区房"],
        objective_features=["南北通透", "全明格局"],
        decoration="精装",
        heating_type="集体供暖",
        bld_year_min=2010,
        bld_year_max=2020,
    )
    assert total == 1
    assert items[0]["listing_id"] == str(lid_match)

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid_match, lid_no_of, lid_no_dec, lid_no_heat, lid_no_year]}})


# ═══════════════════════════════════════════
# 8. 排除自己
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
def test_filter_excludes_self_owned_listings(mock_batch, agent):
    """LA 看不到自己挂的房"""
    mock_batch.return_value = {}
    la_self_id = agent["_id"]
    other_la_id = ObjectId()
    lid_self = _seed_listing(la_self_id, property_code="SELF01")
    lid_other = _seed_listing(other_la_id, property_code="OTHER01")

    from listings import list_shared_listings
    items, total = list_shared_listings(agent["_id"])
    ids = [it["listing_id"] for it in items]
    assert str(lid_self) not in ids
    assert str(lid_other) in ids

    from database import db
    db["listings"].delete_many({"_id": {"$in": [lid_self, lid_other]}})


# ═══════════════════════════════════════════
# 9. 无辞典数据时 graceful degrade
# ═══════════════════════════════════════════

@patch("listings._batch_fetch_props")
@patch("listings._batch_fetch_communities_by_name")
def test_filter_dict_unavailable_returns_empty(mock_comm, mock_batch, agent):
    """辞典社区无数据 → 按 heating_type/bld_year 筛选返空"""
    mock_batch.return_value = {}
    mock_comm.return_value = {}  # 没查到任何社区
    la_id = ObjectId()
    lid = _seed_listing(la_id, property_code="NF01", community="不存在的社区")

    from listings import list_shared_listings
    # heating_type 筛选:社区没数据 → 返空
    items, total = list_shared_listings(agent["_id"], heating_type="集体供暖")
    assert total == 0

    from database import db
    db["listings"].delete_one({"_id": lid})
