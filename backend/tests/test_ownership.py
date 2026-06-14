"""房源归属变更单测:发起锁定 / 护栏 / 复核转移 / 驳回解锁 / 委托强制开关。"""
from bson import ObjectId
import pytest
from fastapi import HTTPException

from database import db
from ownership import create_ownership_change, approve_ownership_change, reject_ownership_change


def _agent(status="active", phone="13900000001", name="接手人"):
    return db["agents"].insert_one(
        {"_id": ObjectId(), "name": name, "phone": phone, "status": status}).inserted_id


def _listing(owner_id=None, status="on_sale"):
    return db["listings"].insert_one({
        "_id": ObjectId(), "community": "测", "status": status,
        "owner_agent_id": owner_id or ObjectId(),
        "owner_agent_name": "原主", "owner_agent_phone": "138",
    }).inserted_id


def test_create_locks_listing():
    _agent()
    lid = _listing()
    res = create_ownership_change(str(lid), "13900000001", "", "离职")
    c = db["ownership_changes"].find_one({"_id": ObjectId(res["id"])})
    assert c["status"] == "pending_review"
    assert db["listings"].find_one({"_id": lid})["ownership_locked"] is True


def test_create_rejects_sold():
    _agent()
    lid = _listing(status="sold")
    with pytest.raises(HTTPException) as e:
        create_ownership_change(str(lid), "13900000001", "", "x")
    assert e.value.status_code == 400


def test_create_rejects_active_tx():
    _agent()
    lid = _listing()
    db["transactions"].insert_one({"listing_id": lid, "status": "pending_la_confirm"})
    with pytest.raises(HTTPException) as e:
        create_ownership_change(str(lid), "13900000001", "", "x")
    assert "进行中的成交" in e.value.detail


def test_create_rejects_banned_target():
    _agent(status="banned", phone="13900000099")
    lid = _listing()
    with pytest.raises(HTTPException):
        create_ownership_change(str(lid), "13900000099", "", "x")


def test_approve_transfers_and_unlocks():
    to = _agent(name="新主")
    lid = _listing()
    res = create_ownership_change(str(lid), "13900000001", "", "离职")
    approve_ownership_change(res["id"])
    l = db["listings"].find_one({"_id": lid})
    assert l["owner_agent_id"] == to and l["owner_agent_name"] == "新主"
    assert l["ownership_locked"] is False
    assert len(l.get("owner_change_history", [])) == 1
    assert db["ownership_changes"].find_one({"_id": ObjectId(res["id"])})["status"] == "approved"


def test_reject_unlocks():
    _agent()
    lid = _listing()
    res = create_ownership_change(str(lid), "13900000001", "", "x")
    reject_ownership_change(res["id"], "凭证不实")
    assert db["listings"].find_one({"_id": lid})["ownership_locked"] is False
    c = db["ownership_changes"].find_one({"_id": ObjectId(res["id"])})
    assert c["status"] == "rejected" and c["review_note"] == "凭证不实"


def test_require_proof_config_off_by_default():
    """种子期默认不强制:无凭证也能发起"""
    _agent()
    lid = _listing()
    res = create_ownership_change(str(lid), "13900000001", "", "x")  # 无 proof
    assert "id" in res


def test_require_proof_config_on_blocks_no_proof():
    from system_config import set_config
    set_config("ownership_require_proof", 1)
    _agent()
    lid = _listing()
    with pytest.raises(HTTPException) as e:
        create_ownership_change(str(lid), "13900000001", "", "x")  # 无 proof
    assert "委托凭证" in e.value.detail
