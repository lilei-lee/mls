"""V2.2 #1 Day 28: seed 3 条测试 listing 用于共享库筛选 curl 联调

幂等:listing 已存在(同 house_code)则跳过创建,仅同步物理。

用法:
  cd C:\projects\mls\backend
  venv\Scripts\activate
  python scripts\seed_v2_2_test_listings.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
import json
import hashlib

BASE = "http://localhost:8000/api/v1"
AGENT_PHONE = "13912345678"
SMS_CODE = "123456"


def login():
    """登录张三,返回 (token, agent_id)."""
    # 发验证码
    requests.post(f"{BASE}/auth/send-sms-code", json={"phone": AGENT_PHONE})
    # 登录
    r = requests.post(f"{BASE}/auth/login", json={"phone": AGENT_PHONE, "code": SMS_CODE})
    data = r.json()
    token = data["access_token"]
    # 拿 agent_id
    me = requests.get(f"{BASE}/me", headers={"Authorization": f"Bearer {token}"}).json()
    agent_id = me["agent_id"]
    print(f"[OK] Login: {me['name']} ({AGENT_PHONE}) agent_id={agent_id}")
    return token, agent_id


def house_code(community, building, unit, room_no):
    raw = f"{community.strip()}#{building.strip()}#{unit.strip()}#{room_no.strip()}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:16]


def create_if_not_exists(token, payload):
    """POST /listings,返 listing dict;409(已存在)则返 None 跳过。"""
    h = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    r = requests.post(f"{BASE}/listings", json=payload, headers=h)
    if r.status_code == 409:
        detail = r.json().get("detail", {})
        print(f"  [SKIP] 已存在: {detail.get('message', str(detail))[:80]}")
        return None
    if r.status_code not in (200, 201):
        print(f"  [FAIL] {r.status_code}: {r.text[:200]}")
        return None
    data = r.json()
    lid = data["listing_id"]
    hc = data["house_code"]
    print(f"  [OK] Created listing {lid} (house_code={hc})")
    return lid


def sync_physical(token, listing_id, body):
    """POST /listings/{id}/sync-physical,返 200+字段列表。"""
    h = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    r = requests.post(f"{BASE}/listings/{listing_id}/sync-physical", json=body, headers=h)
    if r.status_code != 200:
        print(f"  [FAIL] sync-physical {r.status_code}: {r.text[:200]}")
        return None
    data = r.json()
    fields = data.get("synced_fields", [])
    print(f"  [OK] sync-physical: {fields}")
    return data


def main():
    token, agent_id = login()

    # ── 3 条 listing 定义 ──
    listings = [
        {
            "label": "listing 1 · 中泰城 1-1-101",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "1", "unit": "1", "room_no": "101",
                "orientation": "南北", "price_wan": 95,
                "area_sqm": 120, "floor": 5, "total_floor": 18,
                "rooms": 3, "halls": 2, "bathrooms": 1,
                "sale_points": ["学区房", "业主诚意", "满五唯一"],
                "public_remarks": "南北通透全明格局,精装修拎包入住",
                "agent_remarks": "房东诚心出售,底价90万",
                "showing_instructions": "提前2小时预约,全天可看",
            },
            "sync": {
                "objective_features": ["南北通透", "全明格局"],
                "decoration": "精装",
            },
        },
        {
            "label": "listing 2 · 中泰城 1-1-102",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "1", "unit": "1", "room_no": "102",
                "orientation": "南", "price_wan": 75,
                "area_sqm": 88, "floor": 12, "total_floor": 18,
                "rooms": 2, "halls": 1, "bathrooms": 1,
                "sale_points": ["急售可议", "近商圈", "送车位"],
                "public_remarks": "简装两居,总价低适合首套",
                "agent_remarks": "投资客急卖,可大刀",
                "showing_instructions": "随时可看,钥匙在物业",
            },
            "sync": {
                "objective_features": ["客厅朝南"],
                "decoration": "简装",
            },
        },
        {
            "label": "listing 3 · 中泰城 1-2-201",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "1", "unit": "2", "room_no": "201",
                "orientation": "南北", "price_wan": 110,
                "area_sqm": 140, "floor": 2, "total_floor": 18,
                "rooms": 4, "halls": 2, "bathrooms": 2,
                "sale_points": ["学区房", "满五唯一", "电梯洋房"],
                "public_remarks": "大四居,双卫,带入户花园",
                "agent_remarks": "毛坯可自由装修,价格可谈",
                "showing_instructions": "仅周末可看,需提前一天预约",
            },
            "sync": {
                "objective_features": ["南北通透", "卧室朝南"],
                "decoration": "毛坯",
            },
        },
        {
            "label": "listing 4 · 中泰城 1-2-202",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "1", "unit": "2", "room_no": "202",
                "orientation": "南", "price_wan": 130,
                "area_sqm": 135, "floor": 8, "total_floor": 18,
                "rooms": 3, "halls": 2, "bathrooms": 2,
                "sale_points": ["红本在手", "近高铁站", "采光好"],
                "public_remarks": "楼层好,采光极佳",
                "agent_remarks": "业主出国急售,可降到125万",
                "showing_instructions": "工作日下午方便,需提前打电话",
            },
            "sync": {
                "objective_features": ["全南户型"],
                "decoration": "豪装",
            },
        },
        {
            "label": "listing 5 · 中泰城 2-1-301",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "2", "unit": "1", "room_no": "301",
                "orientation": "南北", "price_wan": 88,
                "area_sqm": 105, "floor": 3, "total_floor": 18,
                "rooms": 3, "halls": 1, "bathrooms": 1,
                "sale_points": ["满二", "近公园", "带阳台"],
                "public_remarks": "业主自住保养好,所有家电几乎全新,环境清幽近公园,孩子上下学方便",
                "agent_remarks": "业主诚意度一般,价格相对硬",
                "showing_instructions": "周末上午",
            },
            "sync": {
                "objective_features": ["卧室带卫", "明卫"],
                "decoration": "自住保养好",
            },
        },
        {
            "label": "listing 6 · 中泰城 2-1-302",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "2", "unit": "1", "room_no": "302",
                "orientation": "西", "price_wan": 105,
                "area_sqm": 115, "floor": 10, "total_floor": 18,
                "rooms": 3, "halls": 2, "bathrooms": 1,
                "sale_points": ["不满二", "开放厨房", "带衣帽间"],
                "public_remarks": "开放式厨房+大衣帽间,适合年轻夫妻",
                "agent_remarks": "",
                "showing_instructions": "",
            },
            "sync": {
                "objective_features": ["全明格局"],
                "decoration": "精装",
            },
        },
        {
            "label": "listing 7 · 中泰城 3-1-401",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "3", "unit": "1", "room_no": "401",
                "orientation": "南北", "price_wan": 145,
                "area_sqm": 160, "floor": 4, "total_floor": 18,
                "rooms": 4, "halls": 2, "bathrooms": 2,
                "sale_points": ["学区房", "业主诚意", "次新房", "南向大平层"],
                "public_remarks": "次新精装,业主诚心出售",
                "agent_remarks": "业主因为离婚卖房,可议5-8万",
                "showing_instructions": "推荐,业主有时间随时可看",
            },
            "sync": {
                "objective_features": ["南北通透", "客厅朝南", "卧室朝南"],
                "decoration": "精装",
            },
        },
        {
            "label": "listing 8 · 中泰城 1-1-501",
            "payload": {
                "district": "桥东区", "community": "中泰城",
                "building": "1", "unit": "1", "room_no": "501",
                "orientation": "南", "price_wan": 68,
                "area_sqm": 78, "floor": 5, "total_floor": 6,
                "rooms": 2, "halls": 1, "bathrooms": 1,
                "sale_points": ["业主诚意", "看房方便", "送储物间"],
                "public_remarks": "最低价房源,刚需首选",
                "agent_remarks": "老业主换房急售",
                "showing_instructions": "随时可看",
            },
            "sync": {
                "objective_features": ["卧室阳台"],
                "decoration": "简装",
            },
        },
    ]

    created = []
    for item in listings:
        print(f"\n── {item['label']} ──")
        lid = create_if_not_exists(token, item["payload"])
        if lid:
            created.append(lid)
            sync_physical(token, lid, item["sync"])
        else:
            # listing 已存在,尝试查找已有 listing 做 sync
            hc = house_code(
                item["payload"]["community"],
                item["payload"]["building"],
                item["payload"]["unit"],
                item["payload"]["room_no"],
            )
            # 通 过 GET /listings/mine 查找已有 listing
            h = {"Authorization": f"Bearer {token}"}
            r = requests.get(f"{BASE}/listings/mine?limit=50", headers=h)
            found = None
            for doc in r.json().get("items", []):
                if doc.get("house_code") == hc:
                    found = doc["listing_id"]
                    break
            if found:
                created.append(found)
                sync_physical(token, found, item["sync"])
            else:
                print(f"  [WARN] 已存在但查找失败,无法 sync (house_code={hc})")

    print(f"\n{'='*50}")
    print(f"Total listings seeded: {len(created)}")
    print(f"Listing IDs: {created}")

    # 最终统计
    from database import db
    total = db["listings"].count_documents({})
    print(f"DB total listings: {total}")


if __name__ == "__main__":
    main()
