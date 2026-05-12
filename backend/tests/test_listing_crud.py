"""段 7.3 listing CRUD 双写单测(mock 辞典)"""
import sys, os
sys.path.insert(0, r"C:\projects\mls\backend")

import pytest
from unittest.mock import patch, MagicMock
from bson import ObjectId
from listings import (
    PostListingRequest, _extract_physical_attrs, create_listing,
    get_listing_by_id, DICT_PHYSICAL_FIELDS,
)


@pytest.fixture
def agent():
    return {"_id": ObjectId(), "name": "测试LA", "phone": "13800001111"}


@pytest.fixture
def physical():
    return {"area_sqm": 100.0, "floor": 5, "total_floor": 18, "rooms": 3, "bathrooms": 1}


class FakeReq:
    def __init__(self):
        self.community = "测试小区"
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
        # V2.2 #1: remarks → agent_remarks + public_remarks
        self.agent_remarks = ""
        self.public_remarks = ""
        self.showing_instructions = ""
        self.sale_points = []


def test_extract_physical_attrs():
    req = PostListingRequest(
        district="桥东区", community="测试", building="1", unit="1", room_no="101",
        area_sqm=105.5, floor=6, total_floor=20, rooms=3, bathrooms=2,
        orientation="南", price_wan=90,
    )
    attrs = _extract_physical_attrs(req)
    assert attrs["area_sqm"] == 105.5
    assert attrs["rooms"] == 3
    assert len(attrs) == 5  # V2.2 #2: 删 halls


@patch("dictionary_client.DictionaryClient")
def test_create_listing_happy(mock_client_class, agent, physical):
    """辞典 identify + claim 成功 → listing 插入 + property_code 已写"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "CODE12345678"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    req = FakeReq()
    result = create_listing(req, physical, agent)

    assert result["listing_id"]
    mock_client.identify_property.assert_called_once()
    mock_client.submit_claim.assert_called_once()
    # verify property_code written to DB
    from database import db
    doc = db["listings"].find_one({"_id": ObjectId(result["listing_id"])})
    assert doc["property_code"] == "CODE12345678"
    assert doc["layout"] == "3室1卫"  # V2.2 #2: 删 halls
    # cleanup
    db["listings"].delete_one({"_id": ObjectId(result["listing_id"])})


@patch("dictionary_client.DictionaryClient")
def test_create_listing_unavailable(mock_client_class, agent, physical):
    """辞典不可达 → 503"""
    from dictionary_client import DictionaryUnavailableError
    mock_client = MagicMock()
    mock_client.identify_property.side_effect = DictionaryUnavailableError("down")
    mock_client_class.return_value = mock_client

    req = FakeReq()
    with pytest.raises(Exception) as exc:
        create_listing(req, physical, agent)
    assert exc.value.status_code == 503


@patch("dictionary_client.DictionaryClient")
def test_get_listing_enriched(mock_client_class, agent, physical):
    """GET listing 时从辞典补物理字段"""
    # first create
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "ENRICH123456"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client
    req = FakeReq()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    # now GET with enriched data
    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {
        "authoritative_attrs": {"area_sqm": 105.0, "rooms": 3},
        "attribute_claims": [
            {"field": "bathrooms", "value": 1, "agent_id": "a1", "listing_id": "l1", "claimed_at": "2026-05-01T00:00:00"},
        ],
    }
    mock_client_class.return_value = mock_client2

    detail = get_listing_by_id(lid)
    assert detail["area_sqm"] == 105.0  # from authoritative
    assert detail["rooms"] == 3
    assert detail["bathrooms"] == 1  # from claims_latest

    from database import db
    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_get_listing_no_enrich_without_property_code(mock_client_class, agent, physical):
    """GET listing 时 property_code=None → GET 返回物理字段 None 占位"""
    mock_client = MagicMock()
    mock_client.identify_community.return_value = {"_id": "fake_cid"}
    mock_client.identify_property.return_value = {"property_code": "FAKE001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    req = FakeReq()
    result = create_listing(req, physical, agent)
    lid = result["listing_id"]

    # 手动清掉 property_code 模拟无辞典关联场景
    from database import db
    db["listings"].update_one({"_id": ObjectId(lid)}, {"$unset": {"property_code": ""}})

    detail = get_listing_by_id(lid)
    assert detail["area_sqm"] is None  # 6 物理字段保持 None 占位

    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_list_my_listings_batch_enriched(mock_client_class, agent, physical):
    """list_my_listings batch 富化"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "BATCH01"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    from listings import list_my_listings
    req = FakeReq()
    r = create_listing(req, physical, agent)

    mock_client2 = MagicMock()
    mock_client2.batch_get_properties.return_value = {
        "BATCH01": {"authoritative_attrs": {"area_sqm": 105.0, "rooms": 3}},
    }
    mock_client_class.return_value = mock_client2

    results = list_my_listings(agent["_id"])
    assert len(results) == 1
    assert results[0]["area_sqm"] == 105.0
    assert results[0]["rooms"] == 3

    from database import db
    db["listings"].delete_one({"_id": ObjectId(r["listing_id"])})


@patch("dictionary_client.DictionaryClient")
def test_list_my_listings_dict_unavailable_graceful(mock_client_class, agent, physical):
    """辞典挂,列表仍返 200,物理字段全 None"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "GRACE01"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    req = FakeReq()
    r = create_listing(req, physical, agent)

    mock_client2 = MagicMock()
    mock_client2.batch_get_properties.side_effect = Exception("down")
    mock_client_class.return_value = mock_client2

    from listings import list_my_listings
    results = list_my_listings(agent["_id"])
    assert len(results) >= 1
    for item in results:
        assert item["area_sqm"] is None

    from database import db
    db["listings"].delete_one({"_id": ObjectId(r["listing_id"])})


@patch("dictionary_client.DictionaryClient")
def test_list_listings_no_property_code_skipped(mock_client_class):
    """property_code=None → batch 传空 codes,不调辞典"""
    mock_client = MagicMock()
    mock_client_class.return_value = mock_client

    from listings import _batch_fetch_props
    result = _batch_fetch_props([{"property_code": None}, {"property_code": ""}])
    assert result == {}
    mock_client.batch_get_properties.assert_not_called()


@patch("dictionary_client.DictionaryClient")
def test_get_listing_my_last_claim_la_view(mock_client_class, agent, physical):
    """LA 视角调 GET → my_last_claim 含自己最新 claim,旧值被新值覆盖"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "MYCLAIM001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    req = FakeReq()
    r = create_listing(req, physical, agent)
    lid = r["listing_id"]

    # mock: LA(agent) 提交了 area_sqm old=100 new=105, floor=5
    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {
        "attribute_claims": [
            {"field": "area_sqm", "value": 100, "agent_id": str(agent["_id"]), "listing_id": lid, "claimed_at": "2026-05-01T00:00:00"},
            {"field": "area_sqm", "value": 105, "agent_id": str(agent["_id"]), "listing_id": lid, "claimed_at": "2026-05-02T00:00:00"},
            {"field": "floor",    "value": 8,   "agent_id": str(agent["_id"]), "listing_id": lid, "claimed_at": "2026-05-02T00:00:00"},
        ],
    }
    mock_client_class.return_value = mock_client2

    from listings import get_listing_by_id
    detail = get_listing_by_id(lid, viewer_id=agent["_id"])
    mc = detail["my_last_claim"]
    assert mc["area_sqm"] == 105   # latest wins
    assert mc["floor"] == 8
    assert mc["rooms"] is None      # no claim
    assert mc["bathrooms"] is None
    assert mc["total_floor"] is None

    from database import db
    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_get_listing_no_my_last_claim_ba_view(mock_client_class, agent, physical):
    """BA 视角调 GET → 不含 my_last_claim 字段"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "BACLAIM001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    req = FakeReq()
    r = create_listing(req, physical, agent)
    lid = r["listing_id"]

    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {
        "attribute_claims": [
            {"field": "area_sqm", "value": 100, "agent_id": str(agent["_id"]), "listing_id": lid, "claimed_at": "2026-05-01T00:00:00"},
        ],
    }
    mock_client_class.return_value = mock_client2

    from listings import get_listing_by_id
    ba_id = ObjectId()  # different agent
    detail = get_listing_by_id(lid, viewer_id=ba_id)
    assert "my_last_claim" not in detail

    from database import db
    db["listings"].delete_one({"_id": ObjectId(lid)})


@patch("dictionary_client.DictionaryClient")
def test_get_listing_my_last_claim_filter_only_self(mock_client_class, agent, physical):
    """LA 视角只拿自己的 claim,不混入其他 LA 的"""
    mock_client = MagicMock()
    mock_client.identify_property.return_value = {"property_code": "FILTER001"}
    mock_client.submit_claim.return_value = {"total_claims_after": 1}
    mock_client_class.return_value = mock_client

    req = FakeReq()
    r = create_listing(req, physical, agent)
    lid = r["listing_id"]

    other_la = str(ObjectId())
    mock_client2 = MagicMock()
    mock_client2.get_property.return_value = {
        "attribute_claims": [
            {"field": "area_sqm", "value": 110, "agent_id": other_la, "listing_id": "x", "claimed_at": "2026-05-01T00:00:00"},
            {"field": "area_sqm", "value": 99,  "agent_id": str(agent["_id"]), "listing_id": lid, "claimed_at": "2026-05-02T00:00:00"},
        ],
    }
    mock_client_class.return_value = mock_client2

    from listings import get_listing_by_id
    detail = get_listing_by_id(lid, viewer_id=agent["_id"])
    mc = detail["my_last_claim"]
    assert mc["area_sqm"] == 99  # only self, not 110 from other LA

    from database import db
    db["listings"].delete_one({"_id": ObjectId(lid)})
