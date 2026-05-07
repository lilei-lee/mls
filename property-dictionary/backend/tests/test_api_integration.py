"""Integration test: start uvicorn, hit all 10 endpoints, verify"""
import sys, os, json, time, subprocess, signal

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import json, urllib.request
from database import db

BASE = "http://localhost:8001"

def _get(path, params=None):
    url = f"{BASE}{path}"
    if params:
        from urllib.parse import urlencode
        url += "?" + urlencode(params)
    req = urllib.request.Request(url, method="GET")
    return _do(req)

def _post(path, body):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(f"{BASE}{path}", data=data, method="POST")
    req.add_header("Content-Type", "application/json; charset=utf-8")
    return _do(req)

class FakeResp:
    def __init__(self, status, body):
        self.status_code = status
        self._body = body
    def json(self):
        return json.loads(self._body)
    @property
    def text(self):
        return self._body

def _do(req):
    try:
        with urllib.request.urlopen(req) as resp:
            return FakeResp(resp.status, resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return FakeResp(e.code, e.read().decode("utf-8"))

# Get IDs
zjk = db["cities"].find_one({"name": "张家口"})
qdq = db["districts"].find_one({"city_id": zjk["_id"], "name": "桥东区"})
CITY_ID = str(zjk["_id"])
DISTRICT_ID = str(qdq["_id"])
print(f"CITY={CITY_ID}  DISTRICT={DISTRICT_ID}")

def check(label, resp, expected_code=200):
    status = "OK" if resp.status_code == expected_code else f"FAIL({resp.status_code})"
    print(f"  [{status}] {label}")
    if resp.status_code != expected_code:
        print(f"    body: {resp.text[:300]}")
        return None
    try:
        return resp.json()
    except:
        return resp.text

# 1. health
print("\n=== 1. health ===")
r = _get("/health")
d = check("health", r)
if d: print(f"    {d}")

# 2. identify_community (1st)
print("\n=== 2. identify_community (1st) ===")
r = _post("/v1/communities/identify", {
    "city_id": CITY_ID, "district_id": DISTRICT_ID, "name": "API联调验证小区"
})
c1 = check("create community", r)
if c1:
    print(f"    _id={c1['_id']}  code={c1['community_code']}  name={c1['name']}")
    CID = c1["_id"]
    CCODE = c1["community_code"]

# 3. identify_community (2nd, idempotent)
print("\n=== 3. identify_community (2nd) ===")
r = _post("/v1/communities/identify", {
    "city_id": CITY_ID, "district_id": DISTRICT_ID, "name": "API联调验证小区"
})
c2 = check("idempotent", r)
if c2:
    same = c2["_id"] == CID
    print(f"    same_id={same}  (expected True)")

# 4. get community by code
print("\n=== 4. get_community_by_code ===")
r = _get(f"/v1/communities/{CCODE}")
c3 = check("by code", r)
if c3:
    print(f"    code={c3['community_code']}  name={c3['name']}")

# 5. list communities
print("\n=== 5. list_communities ===")
r = _get("/v1/communities", params={
    "city_id": CITY_ID, "keyword": "API联调"
})
c4 = check("list", r)
if c4:
    print(f"    total={c4['total']}")

# 6. identify_property
print("\n=== 6. identify_property ===")
r = _post("/v1/properties/identify", {
    "city_id": CITY_ID, "district_id": DISTRICT_ID, "community_id": CID,
    "building": "5", "unit": "2", "room_no": "1001",
})
p1 = check("create property", r)
if p1:
    print(f"    code={p1['property_code']}  claims={p1['attribute_claims']}")
    PCODE = p1["property_code"]

# 7. get property by code
print("\n=== 7. get_property_by_code ===")
r = _get(f"/v1/properties/{PCODE}")
p2 = check("by code", r)
if p2:
    print(f"    same_code={p2['property_code'] == PCODE}")

# 8. get property by address
print("\n=== 8. get_property_by_address ===")
r = _get("/v1/properties/by-address", params={
    "city_id": CITY_ID, "district_id": DISTRICT_ID, "community_id": CID,
    "building": "5", "unit": "2", "room_no": "1001",
})
p3 = check("by address", r)
if p3:
    print(f"    match_building={p3['building'] == '5'}")

# 9. 404 test
print("\n=== 9. 404 test ===")
r = _get("/v1/properties/AAAAAAAAAAAA")
check("404", r, expected_code=404)

# 10. community 404
print("\n=== 10. community 404 ===")
r = _get("/v1/communities/ZZZZZZZZZZZZ")
check("community 404", r, expected_code=404)

# Cleanup
print("\n=== cleanup ===")
db["properties"].delete_many({"building": "5", "unit": "2", "room_no": "1001"})
db["communities"].delete_many({"name": "API联调验证小区"})
print("  done")

# Verify clean
pc = db["properties"].count_documents({"building": "5", "unit": "2", "room_no": "1001"})
cc = db["communities"].count_documents({"name": "API联调验证小区"})
print(f"  properties leftover: {pc}")
print(f"  communities leftover: {cc}")
print(f"  {'CLEAN' if pc == 0 and cc == 0 else 'DIRTY!'}")

print("\n=== ALL DONE ===")
