import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from fastapi import HTTPException
from api.auth import check_city_scope


def test_all_scope_passes_any_city():
    meta = {"owner": "test", "city_scope": "all"}
    check_city_scope(meta, "any_city_id")
    check_city_scope(meta, "another_id")

def test_list_scope_allows_listed_city():
    meta = {"owner": "test", "city_scope": ["zjk_id_1", "sjz_id_2"]}
    check_city_scope(meta, "zjk_id_1")
    check_city_scope(meta, "sjz_id_2")

def test_list_scope_rejects_unlisted_city():
    meta = {"owner": "test", "city_scope": ["zjk_id_1"]}
    with pytest.raises(HTTPException) as exc:
        check_city_scope(meta, "other_city_id")
    assert exc.value.status_code == 403
    assert "not authorized for city" in exc.value.detail

def test_list_scope_string_oid_normalization():
    from bson import ObjectId
    oid = ObjectId()
    meta = {"owner": "test", "city_scope": [str(oid)]}
    check_city_scope(meta, oid)
    check_city_scope(meta, str(oid))

def test_invalid_scope_type_rejected():
    meta = {"owner": "test", "city_scope": 123}
    with pytest.raises(HTTPException) as exc:
        check_city_scope(meta, "any")
    assert exc.value.status_code == 403

def test_missing_scope_defaults_to_all():
    meta = {"owner": "test"}
    check_city_scope(meta, "any_city")
