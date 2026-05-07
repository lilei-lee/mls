import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from datetime import datetime
from bson import ObjectId
from database import db
from models.audit_log import audit_logs_collection, ensure_audit_log_indexes


@pytest.fixture(autouse=True)
def cleanup():
    db["audit_logs"].delete_many({"path": {"$regex": "/_test_audit_"}})
    yield
    db["audit_logs"].delete_many({"path": {"$regex": "/_test_audit_"}})


def test_indexes_created():
    idxs = ensure_audit_log_indexes()
    assert "audit_created_desc" in idxs
    assert "audit_owner_time" in idxs
    assert "audit_status" in idxs
    assert "audit_path_time" in idxs

def test_audit_log_doc_shape():
    doc = {
        "method": "POST", "path": "/_test_audit_/sample", "query": None,
        "city_id": str(ObjectId()), "api_key_owner": "mls_self_dev",
        "api_key_prefix": "dev_mls_...", "status_code": 200,
        "request_body_summary": '{"sample":"data"}',
        "ip": "127.0.0.1", "user_agent": "test/1.0",
        "latency_ms": 42, "created_at": datetime.now(),
    }
    result = audit_logs_collection.insert_one(doc)
    found = audit_logs_collection.find_one({"_id": result.inserted_id})
    assert found["method"] == "POST" and found["status_code"] == 200 and found["latency_ms"] == 42

def test_password_redaction():
    from api.middleware.audit import _summarize_body
    body = b'{"name":"test","password":"secret123"}'
    s = _summarize_body(body)
    assert "secret123" not in s and '"password":"***"' in s

def test_summary_truncation():
    from api.middleware.audit import _summarize_body
    s = _summarize_body(b'{"data":"' + b'x' * 500 + b'"}')
    assert len(s) <= 220 and "truncated" in s

def test_extract_city_id_from_query():
    from api.middleware.audit import _extract_city_id
    assert _extract_city_id("/v1/communities", "city_id=abc123&keyword=foo", "") == "abc123"

def test_extract_city_id_from_body():
    from api.middleware.audit import _extract_city_id
    assert _extract_city_id("/v1/identify", "", '{"city_id":"xyz789"}') == "xyz789"

def test_extract_city_id_none():
    from api.middleware.audit import _extract_city_id
    assert _extract_city_id("/v1/properties/CODE", "", "") is None
