"""dictionary_client 24 条单测(12 happy + 12 error)"""
import responses
import pytest
import requests
from dictionary_client import (
    DictionaryClient, DictionaryUnavailableError,
    DictionaryConflictError, DictionaryForbiddenError,
    DictionaryNotFoundError,
)

BASE = "http://localhost:8001/v1"
KEY = "test_key_12345678"


@pytest.fixture
def client():
    return DictionaryClient(base_url=BASE, api_key=KEY)


# ===== happy 12 =====

@responses.activate
def test_identify_property(client):
    responses.add(responses.POST, f"{BASE}/properties/identify",
                  json={"property_code": "CODE01"}, status=200)
    r = client.identify_property("c1", "d1", "m1", "1", "1", "101")
    assert r["property_code"] == "CODE01"

@responses.activate
def test_get_property(client):
    responses.add(responses.GET, f"{BASE}/properties/CODE01",
                  json={"property_code": "CODE01", "building": "1"}, status=200)
    r = client.get_property("CODE01")
    assert r["building"] == "1"

@responses.activate
def test_submit_claim(client):
    responses.add(responses.POST, f"{BASE}/properties/CODE01/claims",
                  json={"total_claims_after": 2}, status=200)
    r = client.submit_claim("CODE01", {"area_sqm": 100}, "a1", "l1")
    assert r["total_claims_after"] == 2

@responses.activate
def test_get_claims(client):
    responses.add(responses.GET, f"{BASE}/properties/CODE01/claims",
                  json={"property_code": "CODE01", "items": []}, status=200)
    r = client.get_claims("CODE01")
    assert r["items"] == []

@responses.activate
def test_sink_transaction(client):
    responses.add(responses.POST, f"{BASE}/properties/CODE01/transactions",
                  json={"added": True, "total_transactions_after": 1}, status=200)
    r = client.sink_transaction("CODE01", 6100000, "2026-04-23")
    assert r["added"] is True

@responses.activate
def test_get_transactions(client):
    responses.add(responses.GET, f"{BASE}/properties/CODE01/transactions",
                  json={"property_code": "CODE01", "items": []}, status=200)
    r = client.get_transactions("CODE01")
    assert r["items"] == []

@responses.activate
def test_identify_community(client):
    responses.add(responses.POST, f"{BASE}/communities/identify",
                  json={"_id": "cid01", "community_code": "COMM01", "name": "测试"}, status=200)
    r = client.identify_community("c1", "d1", "测试")
    assert r["name"] == "测试"

@responses.activate
def test_get_community(client):
    responses.add(responses.GET, f"{BASE}/communities/COMM01",
                  json={"community_code": "COMM01", "name": "测试"}, status=200)
    r = client.get_community("COMM01")
    assert r["name"] == "测试"

@responses.activate
def test_list_communities(client):
    responses.add(responses.GET, f"{BASE}/communities",
                  json={"items": [], "total": 0}, status=200)
    r = client.list_communities("c1")
    assert r["total"] == 0

@responses.activate
def test_batch_get_properties(client):
    responses.add(responses.POST, f"{BASE}/properties/batch",
                  json={"CODE01": {}, "CODE02": None}, status=200)
    r = client.batch_get_properties(["CODE01", "CODE02"])
    assert r["CODE02"] is None

@responses.activate
def test_list_discrepancies(client):
    responses.add(responses.GET, f"{BASE}/discrepancies",
                  json={"items": [], "total": 0}, status=200)
    r = client.list_discrepancies()
    assert r["total"] == 0

@responses.activate
def test_get_discrepancy(client):
    responses.add(responses.GET, f"{BASE}/discrepancies/disc01",
                  json={"_id": "disc01", "status": "pending"}, status=200)
    r = client.get_discrepancy("disc01")
    assert r["status"] == "pending"


# ===== error 12 =====

@responses.activate
def test_identify_property_5xx_retry_exhausted(client):
    responses.add(responses.POST, f"{BASE}/properties/identify", status=500)
    responses.add(responses.POST, f"{BASE}/properties/identify", status=500)
    with pytest.raises(DictionaryUnavailableError):
        client.identify_property("c1", "d1", "m1", "1", "1", "101")

@responses.activate
def test_get_property_404(client):
    responses.add(responses.GET, f"{BASE}/properties/NOCODE", status=404)
    with pytest.raises(DictionaryNotFoundError):
        client.get_property("NOCODE")

@responses.activate
def test_submit_claim_409(client):
    responses.add(responses.POST, f"{BASE}/properties/CODE01/claims",
                  json={"detail": "conflict", "diff": {"area_sqm": [100, 105]}}, status=409)
    with pytest.raises(DictionaryConflictError) as exc:
        client.submit_claim("CODE01", {"area_sqm": 105}, "a1", "l1")
    assert exc.value.diff == {"area_sqm": [100, 105]}

@responses.activate
def test_get_claims_403(client):
    responses.add(responses.GET, f"{BASE}/properties/CODE01/claims", status=403)
    with pytest.raises(DictionaryForbiddenError):
        client.get_claims("CODE01")

@responses.activate
def test_get_transactions_connection_error(client):
    responses.add(responses.GET, f"{BASE}/properties/CODE01/transactions",
                  body=requests.ConnectionError("refused"))
    responses.add(responses.GET, f"{BASE}/properties/CODE01/transactions",
                  body=requests.ConnectionError("refused"))
    with pytest.raises(DictionaryUnavailableError):
        client.get_transactions("CODE01")

@responses.activate
def test_get_community_5xx_retry_success(client):
    responses.add(responses.GET, f"{BASE}/communities/COMM01", status=503)
    responses.add(responses.GET, f"{BASE}/communities/COMM01",
                  json={"community_code": "COMM01", "name": "测试"}, status=200)
    r = client.get_community("COMM01")
    assert r["name"] == "测试"

@responses.activate
def test_sink_transaction_400(client):
    responses.add(responses.POST, f"{BASE}/properties/CODE01/transactions",
                  json={"detail": "Invalid price"}, status=400)
    with pytest.raises(ValueError):
        client.sink_transaction("CODE01", -1, "2026-04-23")

@responses.activate
def test_identify_community_timeout(client):
    responses.add(responses.POST, f"{BASE}/communities/identify",
                  body=requests.Timeout())
    responses.add(responses.POST, f"{BASE}/communities/identify",
                  body=requests.Timeout())
    with pytest.raises(DictionaryUnavailableError):
        client.identify_community("c1", "d1", "测试")

@responses.activate
def test_list_communities_403(client):
    responses.add(responses.GET, f"{BASE}/communities", status=403)
    with pytest.raises(DictionaryForbiddenError):
        client.list_communities("c1")

@responses.activate
def test_list_discrepancies_5xx_retry_success(client):
    responses.add(responses.GET, f"{BASE}/discrepancies", status=502)
    responses.add(responses.GET, f"{BASE}/discrepancies",
                  json={"items": [], "total": 0}, status=200)
    r = client.list_discrepancies()
    assert r["total"] == 0

@responses.activate
def test_get_discrepancy_409(client):
    responses.add(responses.GET, f"{BASE}/discrepancies/disc01", status=409)
    with pytest.raises(DictionaryConflictError):
        client.get_discrepancy("disc01")

@responses.activate
def test_batch_get_properties_400(client):
    responses.add(responses.POST, f"{BASE}/properties/batch",
                  json={"detail": "codes too long"}, status=400)
    with pytest.raises(ValueError):
        client.batch_get_properties(["X" * 12] * 101)
