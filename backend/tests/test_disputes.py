"""争议举报(经纪人端)单测。"""
from bson import ObjectId

from database import db
from disputes import FileDisputeBody, file_dispute


def test_file_dispute_inserts_pending():
    reporter = {"_id": ObjectId(), "name": "李红"}
    body = FileDisputeBody(target_type="agent", target_id=str(ObjectId()),
                           reason="截客", description="对方私下与我的客户成交")
    res = file_dispute(body, reporter)
    d = db["disputes"].find_one({"_id": ObjectId(res["dispute_id"])})
    assert d["status"] == "pending"
    assert d["reporter_name"] == "李红"
    assert d["reason"] == "截客"
    assert d["penalty"] is None


def test_file_dispute_transaction_target():
    reporter = {"_id": ObjectId(), "name": "张三"}
    body = FileDisputeBody(target_type="transaction", target_id=str(ObjectId()),
                           reason="价格异常", description="成交价明显偏离")
    res = file_dispute(body, reporter)
    d = db["disputes"].find_one({"_id": ObjectId(res["dispute_id"])})
    assert d["target_type"] == "transaction"
