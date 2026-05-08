"""MLS 调辞典 HTTP 客户端,封装 property-dictionary 侧全部 12 endpoint"""
import os
import time
import requests
from typing import Optional


DICT_BASE_URL = os.getenv("DICT_BASE_URL", "http://localhost:8001/v1")
DICT_API_KEY = os.getenv("DICT_API_KEY", "")


class DictionaryError(Exception):
    """辞典客户端基础异常"""
    pass


class DictionaryUnavailableError(DictionaryError):
    """网络错误 / 5xx 重试后仍失败"""
    pass


class DictionaryConflictError(DictionaryError):
    """409 冲突,带 diff 详情"""
    def __init__(self, detail, diff=None):
        self.diff = diff
        super().__init__(detail)


class DictionaryForbiddenError(DictionaryError):
    """403 API Key 无效或 city_scope 越界"""
    pass


class DictionaryNotFoundError(DictionaryError):
    """404 code 不存在"""
    pass


class DictionaryClient:
    def __init__(self, base_url=None, api_key=None):
        self.base_url = (base_url or DICT_BASE_URL).rstrip("/")
        self.api_key = api_key or DICT_API_KEY

    def _request(self, method, path, body=None, params=None, retries=1):
        url = f"{self.base_url}{path}"
        headers = {"X-API-Key": self.api_key}
        if body is not None:
            headers["Content-Type"] = "application/json"

        for attempt in range(retries + 1):
            try:
                r = requests.request(
                    method, url, json=body, params=params,
                    headers=headers, timeout=5,
                )
                if r.status_code in (200, 201):
                    return r.json()
                if r.status_code == 400:
                    raise ValueError(r.text[:500])
                if r.status_code == 403:
                    raise DictionaryForbiddenError(r.text[:500])
                if r.status_code == 404:
                    raise DictionaryNotFoundError(r.text[:500])
                if r.status_code == 409:
                    data = r.json() if r.text else {}
                    raise DictionaryConflictError(
                        r.text[:500],
                        diff=data.get("diff") if isinstance(data, dict) else None,
                    )
                if r.status_code >= 500:
                    if attempt < retries:
                        time.sleep(0.2)
                        continue
                    raise DictionaryUnavailableError(
                        f"5xx after {retries + 1} attempts: {r.status_code} {r.text[:200]}"
                    )
            except (requests.ConnectionError, requests.Timeout) as e:
                if attempt < retries:
                    time.sleep(0.2)
                    continue
                raise DictionaryUnavailableError(str(e))
        raise DictionaryUnavailableError("unreachable")

    # ── 身份层 ──
    def identify_property(self, city_id, district_id, community_id, building, unit, room_no):
        return self._request("POST", "/properties/identify", body={
            "city_id": city_id, "district_id": district_id,
            "community_id": community_id,
            "building": building, "unit": unit, "room_no": room_no,
        })

    def get_property(self, code):
        return self._request("GET", f"/properties/{code}")

    # ── 物理属性层 ──
    def submit_claim(self, code, attrs, agent_id, listing_id=None):
        body = {"agent_id": agent_id, "claims": attrs}
        if listing_id:
            body["listing_id"] = listing_id
        return self._request("POST", f"/properties/{code}/claims", body=body)

    def get_claims(self, code, field=None):
        params = {"field": field} if field else None
        return self._request("GET", f"/properties/{code}/claims", params=params)

    # ── 交易沉淀 ──
    def sink_transaction(self, code, deal_price_yuan, deal_date,
                         source="mls_internal", transaction_id=None, verified=False):
        return self._request("POST", f"/properties/{code}/transactions", body={
            "deal_price_yuan": deal_price_yuan,
            "deal_date": deal_date,
            "source": source,
            "transaction_id": transaction_id,
            "verified": verified,
        })

    def get_transactions(self, code, source=None):
        params = {"source": source} if source else None
        return self._request("GET", f"/properties/{code}/transactions", params=params)

    # ── 字典层 ──
    def identify_community(self, city_id, district_id, name):
        return self._request("POST", "/communities/identify", body={
            "city_id": city_id, "district_id": district_id, "name": name,
        })

    def get_community(self, code):
        return self._request("GET", f"/communities/{code}")

    def list_communities(self, city_id, keyword=None, limit=50):
        params = {"city_id": city_id, "limit": limit}
        if keyword:
            params["keyword"] = keyword
        return self._request("GET", "/communities", params=params)

    # ── 批量层 ──
    def batch_get_properties(self, codes):
        return self._request("POST", "/properties/batch", body={"codes": codes})

    # ── discrepancy ──
    def list_discrepancies(self, city_id=None, limit=50):
        params = {"limit": limit}
        if city_id:
            params["city_id"] = city_id
        return self._request("GET", "/discrepancies", params=params)

    def get_discrepancy(self, disc_id):
        return self._request("GET", f"/discrepancies/{disc_id}")
