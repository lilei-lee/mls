"""V2.2 #1 Day 27: listing 4 字段 + sync-physical 扩展 + 权限分层 单测"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from unittest.mock import patch, MagicMock
from bson import ObjectId


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "测试LA", "phone": "13800001111"}


@pytest.fixture
def physical():
    return {"area_sqm": 100.0, "floor": 5, "total_floor": 18, "rooms": 3, "bathrooms": 1}


class FakeReqV2:
    def __init__(self, **overrides):
        self.community = "测试小区V2"
        self.building = "1"
        self.unit = "1"
        self.room_no = "101"
        self.district = "桥东区"
        self.community_id = str(ObjectId())
        self.city_id = str(ObjectId())
        self.district_id = str(ObjectId())
        self.orientation = "南"
        self.price_wan = 80.0
        self.bonus_yuan = 0
        self.cover_thumbnail = None
        self.photos = None
        self.agent_remarks = ""
        self.public_remarks = ""
        self.showing_instructions = ""
        self.sale_points = []
        for k, v in overrides.items():
            setattr(self, k, v)


# ═══════════════════════════════════════════
# 1. 4 字段创建
# ═══════════════════════════════════════════

@patch("dictionary_client.DictionaryClient")
def test_listing_create_with_4_fields(mock_client_class, agent, physical):
    """创建 listing 时 4 个新字段正确落库"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "V22NEW001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing
    req = FakeReqV2(
        sale_points=["满五唯一", "近公园", "MyCustomTag"],
        public_remarks="小区环境好,适合居家",
        agent_remarks="房东急售,底价 75 万",
        showing_instructions="提前半小时预约,周末全天可看",
    )
    result = create_listing(req, physical, agent)

    from database import db
    doc = db["listings"].find_one({"_id": ObjectId(result["listing_id"])})
    assert doc["sale_points"] == ["满五唯一", "近公园", "MyCustomTag"]
    assert doc["public_remarks"] == "小区环境好,适合居家"
    assert doc["agent_remarks"] == "房东急售,底价 75 万"
    assert doc["showing_instructions"] == "提前半小时预约,周末全天可看"
    # 旧 remarks 字段不应存在
    assert "remarks" not in doc

    db["listings"].delete_one({"_id": ObjectId(result["listing_id"])})


@patch("dictionary_client.DictionaryClient")
def test_listing_create_with_empty_4_fields(mock_client_class, agent, physical):
    """4 字段全空不传时落库空字符串/空数组"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "V22NEW002"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing
    req = FakeReqV2()  # all defaults
    result = create_listing(req, physical, agent)

    from database import db
    doc = db["listings"].find_one({"_id": ObjectId(result["listing_id"])})
    assert doc["sale_points"] == []
    assert doc["public_remarks"] == ""
    assert doc["agent_remarks"] == ""
    assert doc["showing_instructions"] == ""

    db["listings"].delete_one({"_id": ObjectId(result["listing_id"])})


# ═══════════════════════════════════════════
# 2. 4 字段更新
# ═══════════════════════════════════════════

@patch("dictionary_client.DictionaryClient")
def test_listing_update_with_4_fields(mock_client_class, agent, physical):
    """更新 listing 时 4 个新字段正确落库"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "V22UPD001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, update_listing
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    update_listing(lid, {
        "sale_points": ["红本在手", "送车位"],
        "public_remarks": "更新后的公开备注",
        "agent_remarks": "更新后的经纪人备注",
        "showing_instructions": "更新后的看房指引",
    }, agent["_id"])

    doc = db["listings"].find_one({"_id": ObjectId(lid)})
    assert doc["sale_points"] == ["红本在手", "送车位"]
    assert doc["public_remarks"] == "更新后的公开备注"
    assert doc["agent_remarks"] == "更新后的经纪人备注"
    assert doc["showing_instructions"] == "更新后的看房指引"

    db["listings"].delete_one({"_id": ObjectId(lid)})


# ═══════════════════════════════════════════
# 3. sale_points 校验
# ═══════════════════════════════════════════

def test_listing_sale_points_validation_invalid():
    """非法 sale_points 被拒绝(Pydantic validator)"""
    from services.listings import PostListingRequest
    import pydantic

    with pytest.raises(pydantic.ValidationError):
        PostListingRequest(
            district="桥东区", community="测试", building="1", unit="1", room_no="101",
            area_sqm=100, floor=5, total_floor=18, rooms=3, bathrooms=2,
            orientation="南", price_wan=90,
            sale_points=["ThisTagIsWayTooLongFor12Chars"],
        )


def test_listing_sale_points_max_25():
    """超过 25 个标签被拒绝"""
    from services.listings import PostListingRequest
    import pydantic
    from const.sale_points import PRESET_SALE_POINTS

    # 21 预设 + 5 自定义 = 26 > 25
    tags = list(PRESET_SALE_POINTS) + ["A", "B", "C", "D", "E"]

    with pytest.raises(pydantic.ValidationError):
        PostListingRequest(
            district="桥东区", community="测试", building="1", unit="1", room_no="101",
            area_sqm=100, floor=5, total_floor=18, rooms=3, bathrooms=2,
            orientation="南", price_wan=90,
            sale_points=tags,
        )


# ═══════════════════════════════════════════
# 4. remarks 字段已删
# ═══════════════════════════════════════════

def test_listing_remarks_field_removed_from_request():
    """CreateListingRequest 不再接受 remarks 字段"""
    from services.listings import CreateListingRequest, PostListingRequest

    # CreateListingRequest and PostListingRequest no longer have remarks
    assert "remarks" not in CreateListingRequest.model_fields
    assert "remarks" not in PostListingRequest.model_fields


def test_listing_remarks_field_not_in_allowed_update():
    """update_listing 的 allowed 集合不含 remarks"""
    # 直接验证 format 输出不含 remarks
    from services.listings import _format_listing_full
    doc = {
        "_id": ObjectId(), "house_code": "test", "district": "桥东区",
        "community": "测试", "community_id": ObjectId(),
        "building": "1", "unit": "1", "room_no": "101",
        "property_code": "TEST01",
        "layout": "3室1厅1卫", "orientation": "南", "price_wan": 100,
        "agent_remarks": "agent note", "public_remarks": "public note",
        "showing_instructions": "instr", "sale_points": [],
        "bonus_yuan": 0, "status": "on_sale",
        "cover_thumbnail": None, "photos": [], "photo_count": 0,
        "owner_agent_id": ObjectId(), "owner_agent_name": "测试",
        "owner_agent_phone": "13800001111",
        "created_at": __import__("datetime").datetime.now(),
        "updated_at": __import__("datetime").datetime.now(),
    }
    r = _format_listing_full(doc)
    assert "remarks" not in r
    assert "agent_remarks" in r
    assert "public_remarks" in r
    assert "showing_instructions" in r
    assert "sale_points" in r


# ═══════════════════════════════════════════
# 5. 权限分层
# ═══════════════════════════════════════════

@patch("dictionary_client.DictionaryClient")
def test_get_listing_collaboration_locked(mock_client_class, agent, physical):
    """BA 无协作关系 → 不返 agent_remarks / showing_instructions / LA 手机号"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "LOCKED001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, get_listing_by_id
    from database import db

    req = FakeReqV2(
        agent_remarks="机密备注",
        showing_instructions="看房指引",
    )
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {}
    mock_client_class.return_value = mock_client2

    ba_id = ObjectId()  # unrelated BA
    detail = get_listing_by_id(lid, viewer_id=ba_id)
    assert detail["agent_remarks"] == ""
    assert detail["showing_instructions"] == ""
    assert detail["owner_agent_phone"] == ""

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_get_listing_collaboration_unlocked_la(mock_client_class, agent, physical):
    """LA 看自己 → 返全字段含 agent_remarks / showing_instructions / 手机号"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "UNLOCK001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, get_listing_by_id
    from database import db

    req = FakeReqV2(
        agent_remarks="LA 自己备注",
        showing_instructions="LA 自己指引",
    )
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {}
    mock_client_class.return_value = mock_client2

    detail = get_listing_by_id(lid, viewer_id=agent["_id"])
    assert detail["agent_remarks"] == "LA 自己备注"
    assert detail["showing_instructions"] == "LA 自己指引"
    assert detail["owner_agent_phone"] == "13800001111"

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_get_listing_collaboration_unlocked_ba(mock_client_class, agent, physical):
    """BA 有 approved showing_request → 返全字段"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "UNLOCK002"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, get_listing_by_id
    from database import db

    req = FakeReqV2(
        agent_remarks="BA 可见备注",
        showing_instructions="BA 可见指引",
    )
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    ba_id = ObjectId()
    # 创建 approved showing_request
    db["showing_requests"].insert_one({
        "listing_id": ObjectId(lid),
        "buyer_agent_id": ba_id,
        "listing_agent_id": agent["_id"],
        "status": "approved",
        "created_at": __import__("datetime").datetime.now(),
    })

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {}
    mock_client_class.return_value = mock_client2

    detail = get_listing_by_id(lid, viewer_id=ba_id)
    assert detail["agent_remarks"] == "BA 可见备注"
    assert detail["showing_instructions"] == "BA 可见指引"
    assert detail["owner_agent_phone"] == "13800001111"

    db["showing_requests"].delete_many({"listing_id": ObjectId(lid)})
    db["listings"].delete_one({"_id": ObjectId(lid)})


# ═══════════════════════════════════════════
# 6. sync-physical 扩展
# ═══════════════════════════════════════════

@patch("dictionary_client.DictionaryClient")
def test_sync_physical_with_objective_features(mock_client_class, agent, physical):
    """sync-physical 接受 objective_features 并调辞典 claim"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "SYNC001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1, "comparison_results": []}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, sync_physical_to_dict, SyncPhysicalBody
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    # Reset mock to capture sync call
    mock_client2 = MagicMock()
    mock_client2.submit_claim.return_value = {"total_claims_after": 2, "comparison_results": []}
    mock_client_class.return_value = mock_client2

    body = SyncPhysicalBody(objective_features=["南北通透", "全明格局"])
    sync_result = sync_physical_to_dict(lid, body, agent["_id"])

    assert "objective_features" in sync_result["synced_fields"]
    assert sync_result["synced_values"]["objective_features"] == ["南北通透", "全明格局"]

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_with_decoration(mock_client_class, agent, physical):
    """sync-physical 接受 decoration 并调辞典 claim"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "SYNC002"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1, "comparison_results": []}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, sync_physical_to_dict, SyncPhysicalBody
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.submit_claim.return_value = {"total_claims_after": 2, "comparison_results": []}
    mock_client_class.return_value = mock_client2

    body = SyncPhysicalBody(decoration="精装")
    sync_result = sync_physical_to_dict(lid, body, agent["_id"])

    assert "decoration" in sync_result["synced_fields"]
    assert sync_result["synced_values"]["decoration"] == "精装"

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_sync_physical_optional_fields_not_in_attrs_when_none(mock_client_class, agent, physical):
    """objective_features/decoration 为 None 时不包含在 attrs 中"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "SYNC003"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1, "comparison_results": []}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, sync_physical_to_dict, SyncPhysicalBody
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.submit_claim.return_value = {"total_claims_after": 1, "comparison_results": []}
    mock_client_class.return_value = mock_client2

    # Only physical fields, no optional fields
    body = SyncPhysicalBody(area_sqm=120.5, floor=8)
    sync_result = sync_physical_to_dict(lid, body, agent["_id"])

    assert "objective_features" not in sync_result["synced_fields"]
    assert "decoration" not in sync_result["synced_fields"]
    assert "area_sqm" in sync_result["synced_fields"]

    db["listings"].delete_one({"_id": ObjectId(lid)})


# ═══════════════════ V2.3 #1: BA 越权脱敏 ═══════════════════

@patch("dictionary_client.DictionaryClient")
def test_ba_without_collab_masked(mock_client_class, agent, physical):
    """BA 未协作→building/unit/room_no/house_code/owner_name 全空"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "SEC01"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, get_listing_by_id
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {}
    mock_client_class.return_value = mock_client2

    ba_id = ObjectId()
    detail = get_listing_by_id(lid, viewer_id=ba_id)
    assert detail["building"] == ""
    assert detail["unit"] == ""
    assert detail["room_no"] == ""
    assert detail["house_code"] == ""
    assert detail["owner_agent_name"] == ""
    assert detail["_is_owner"] is False

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_la_sees_full(mock_client_class, agent, physical):
    """LA 自己→全字段+_is_owner=True"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "SEC02"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, get_listing_by_id
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {}
    mock_client_class.return_value = mock_client2

    detail = get_listing_by_id(lid, viewer_id=agent["_id"])
    assert detail["building"] == "1"
    assert detail["unit"] == "1"
    assert detail["room_no"] == "101"
    assert detail["house_code"] != ""
    assert detail["_is_owner"] is True

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_ba_with_collab_unmasked(mock_client_class, agent, physical):
    """BA 协作通过→全字段+_is_owner=False"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "SEC03"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from services.listings import create_listing, get_listing_by_id
    from database import db

    req = FakeReqV2()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    ba_id = ObjectId()
    db["showing_requests"].insert_one({
        "listing_id": ObjectId(lid),
        "buyer_agent_id": ba_id,
        "listing_agent_id": agent["_id"],
        "status": "approved",
        "created_at": __import__("datetime").datetime.now(),
    })

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {}
    mock_client_class.return_value = mock_client2

    detail = get_listing_by_id(lid, viewer_id=ba_id)
    assert detail["building"] == "1"
    assert detail["_is_owner"] is False
    assert detail["_can_edit"] is False

    db["showing_requests"].delete_many({"listing_id": ObjectId(lid)})
    db["listings"].delete_one({"_id": ObjectId(lid)})
