"""audit_logs 集合 — 写操作自动留痕"""
from pymongo import ASCENDING, DESCENDING
from database import db

audit_logs_collection = db["audit_logs"]


def ensure_audit_log_indexes() -> list[str]:
    audit_logs_collection.create_index([("created_at", DESCENDING)], name="audit_created_desc")
    audit_logs_collection.create_index([("api_key_owner", ASCENDING), ("created_at", DESCENDING)], name="audit_owner_time")
    audit_logs_collection.create_index([("status_code", ASCENDING)], name="audit_status")
    audit_logs_collection.create_index([("path", ASCENDING), ("created_at", DESCENDING)], name="audit_path_time")
    return list(audit_logs_collection.index_information().keys())
