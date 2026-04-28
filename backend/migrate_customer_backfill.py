"""
MLS Day 17 · 数据迁移脚本:历史"无 customer_id"协作回填

背景
----
Day 12 之前的协作申请里 customer_id 是空的(当时还没有 customers 集合),
只有扁平的 customer_surname / customer_gender / requirements 字段。
Day 12 起 customers 模块上线,但历史数据没有回填,导致:
1. 客户选择器看不到老协作对应的客户
2. 同一 BA 对同一"姓氏+性别"可能有多个重复客户档案

归并规则
--------
1. 扫描所有 showing_requests 中 customer_id 为 null / 不存在的条目
2. 按 (buyer_agent_id, customer_surname, customer_gender, listing_id) 分组
3. 对每个组:
   a. 先看同组内是否有 showing_request 已带有 customer_id(部分回填的数据)
      → 有则复用该 customer_id
      → 没有则新建一条 customer(取该组最早一条的 requirements)

只处理 customer_id 为 null 或不存在的条目,已有关联的不碰。

归并键设计理由
--------------
历史回填分组键: (buyer_agent_id, customer_surname, customer_gender, listing_id)
日常去重分组键: (buyer_agent_id, customer_surname, customer_gender) + 人工确认

为什么回填用 4 字段强键:
- 张家口本地 BA 手里同姓同性别的客户碰撞概率很高
- 两条历史申请只有"同 BA + 同姓 + 同性别 + 同房源"才有足够证据判定同一客户
- 回填目标是"补 customer_id 缺失",不是"客户去重"
- 静默自动合并同名不同人的客户是数据灾难;宁可多建档案让 BA 手动合并

日常去重用 3 字段弱键 + 人工:
- 客户跟人不跟房,BA 新建客户时应考虑同名去重
- 但这是 BA 在 UI 里的判断,不是脚本该做的
- 脚本只负责"补漏",补漏必须保守

与 Day 15 迁移的关系
--------------------
Day 15 脚本(migrate_collab_1n.py)只做了"重复申请归并",不做 customer_id 回填。
本脚本补上 Day 15 未覆盖的 customer_id 回填逻辑。

用法
----
预览(默认,不写库):
    python migrate_customer_backfill.py

真改(加 --apply):
    python migrate_customer_backfill.py --apply

(真改前会自动 dump showing_requests 到 showing_requests_backup_day17,
 customers 到 customers_backup_day17)
"""

import argparse
from datetime import datetime
from collections import defaultdict

from database import db


def make_group_key(req: dict) -> tuple:
    """历史回填分组键: (buyer_agent_id, surname, gender, listing_id)

    强证据键:两条申请只有在同 BA + 同姓 + 同性别 + 同房源时,
    才有足够证据判定是同一个客户。
    """
    snap = req.get("listing_snapshot", {})
    listing_id = snap.get("listing_id") or ""
    # 如果 listing_id 在 snapshot 里没有,尝试用 top-level 字段
    if not listing_id:
        listing_id = str(req.get("listing_id", ""))
    return (
        str(req.get("buyer_agent_id", "")),
        req.get("customer_surname", "") or "",
        req.get("customer_gender", "") or "",
        listing_id,
    )


def find_backfill_groups() -> list[dict]:
    """找出所有 customer_id 为空的历史申请,按分组聚合"""
    cursor = db["showing_requests"].find({
        "$or": [
            {"customer_id": None},
            {"customer_id": {"$exists": False}},
            {"customer_id": ""},
        ]
    })

    groups: dict[tuple, list] = defaultdict(list)
    for req in cursor:
        key = make_group_key(req)
        # 跳过键不完整的脏数据
        if not key[0] or not key[1] or not key[2]:
            continue
        groups[key].append(req)

    # 按 buyer_agent_id 排序,每组按 created_at 排序
    result = []
    for key, reqs in groups.items():
        reqs.sort(key=lambda r: r.get("created_at") or datetime.min)
        snap = reqs[0].get("listing_snapshot", {})
        listing_id = snap.get("listing_id") or str(reqs[0].get("listing_id", ""))
        community = snap.get("community", "?")
        building = snap.get("building", "")
        unit = snap.get("unit", "")
        room_no = snap.get("room_no", "")
        result.append({
            "buyer_agent_id": key[0],
            "surname": key[1],
            "gender": key[2],
            "listing_id": listing_id,
            "community": community,
            "building": building,
            "unit": unit,
            "room_no": room_no,
            "requests": reqs,
        })

    result.sort(key=lambda g: (g["buyer_agent_id"], g["surname"], g["gender"]))
    return result


def find_existing_customer_in_group(group: dict) -> str | None:
    """在同组 showing_requests 中找已有 customer_id(部分回填数据)

    返回 customer_id 字符串或 None。
    如果同组内没有任何 showing_request 带 customer_id,说明全是纯扁平老数据,需新建。
    """
    from bson import ObjectId
    for req in group["requests"]:
        cid = req.get("customer_id")
        if cid:
            return str(cid)
    # 进一步:查 customers 集合中是否有同 BA + 同姓 + 同性别
    # 且该 customer 是通过其他 showing_request 关联到同房源的
    # 这属于"跨组已有匹配",保守起见不做。只建不并。
    return None


def preview(groups: list[dict]) -> None:
    """打印回填预览"""
    if not groups:
        print("[OK] 没有需要回填的历史申请,DB 已经干净。")
        return

    print(f"WARNING: 发现 {len(groups)} 组无 customer_id 的历史申请,将回填:\n")

    new_customers = 0
    existing_customers = 0
    total_requests = 0

    for i, group in enumerate(groups, 1):
        ba_id = group["buyer_agent_id"]
        surname = group["surname"]
        gender = group["gender"]
        reqs = group["requests"]
        listing_id = group.get("listing_id", "?")
        community = group.get("community", "?")
        building = group.get("building", "")
        unit = group.get("unit", "")
        room_no = group.get("room_no", "")
        addr = f"{community} {building}-{unit}-{room_no}"

        # 查同组是否有已回填的 customer_id
        existing_cid = find_existing_customer_in_group(group)

        gender_label = {"male": "先生", "female": "女士"}.get(gender, "")

        print(f"--- 组 {i} ---")
        print(f"  BA={str(ba_id)[:8]}..  客户={surname}{gender_label}")
        print(f"  房源={addr}  listing_id={listing_id}")

        if existing_cid:
            print(f"  [OK] 同组已有 customer_id: {existing_cid[:8]}..,将复用")
            existing_customers += 1
        else:
            first_req = reqs[0]
            requirements = (first_req.get("requirements", "") or "")[:50]
            print(f"  [NEW] 将新建客户: surname={surname} gender={gender} requirements='{requirements}'")
            new_customers += 1

        print(f"  [LINK] 关联 {len(reqs)} 条 showing_request -> customer_id")
        for r in reqs:
            created = r.get("created_at")
            created_str = created.strftime("%Y-%m-%d %H:%M") if created else "?"
            print(f"      req={str(r['_id'])[:8]}..  created={created_str}  status={r.get('status')}")
        total_requests += len(reqs)
        print()

    print(f"[SUMMARY] 总结:")
    print(f"  - 历史申请总数: {total_requests} 条")
    print(f"  - 需新建客户档案: {new_customers} 个")
    print(f"  - 已有匹配档案: {existing_customers} 个")
    print(f"  - 将回填 customer_id: {total_requests} 条 showing_request")
    print()
    print("[INFO] 这是 dry-run,未做任何修改。加 --apply 真改。")


def apply_backfill(groups: list[dict]) -> None:
    """真执行回填"""
    if not groups:
        print("✅ 没有需要回填的,直接退出。")
        return

    print("[LOCK] 第一步:备份集合")

    # 备份 showing_requests
    sr_backup = "showing_requests_backup_day17"
    existing_sr = db[sr_backup].count_documents({})
    if existing_sr > 0:
        print(f"   备份集合 {sr_backup} 已存在({existing_sr} 条),跳过")
    else:
        list(db["showing_requests"].aggregate([{"$out": sr_backup}]))
        print(f"   已备份 {db[sr_backup].count_documents({})} 条到 `{sr_backup}`")

    # 备份 customers
    cust_backup = "customers_backup_day17"
    existing_cust = db[cust_backup].count_documents({})
    if existing_cust > 0:
        print(f"   备份集合 {cust_backup} 已存在({existing_cust} 条),跳过")
    else:
        list(db["customers"].aggregate([{"$out": cust_backup}]))
        print(f"   已备份 {db[cust_backup].count_documents({})} 条到 `{cust_backup}`")
    print()

    now = datetime.now()
    new_count = 0
    existing_count = 0
    backfilled = 0

    for group in groups:
        ba_id = group["buyer_agent_id"]
        surname = group["surname"]
        gender = group["gender"]
        reqs = group["requests"]

        from bson import ObjectId
        ba_oid = ObjectId(ba_id)

        # 1. 找或建客户:同组已有 customer_id 则复用,否则新建
        existing_cid = find_existing_customer_in_group(group)
        if existing_cid:
            customer_id = ObjectId(existing_cid)
            existing_count += 1
        else:
            first_req = reqs[0]
            requirements = (first_req.get("requirements", "") or "").strip()
            customer_doc = {
                "owner_agent_id": ba_oid,
                "surname": surname,
                "gender": gender,
                "phone": None,
                "requirements": requirements,
                "memo_entries": [],
                "status": "active",
                "created_at": first_req.get("created_at", now),
                "updated_at": now,
            }
            result = db["customers"].insert_one(customer_doc)
            customer_id = result.inserted_id
            new_count += 1

        # 2. 回填所有 showing_request 的 customer_id
        for r in reqs:
            db["showing_requests"].update_one(
                {"_id": r["_id"]},
                {"$set": {
                    "customer_id": customer_id,
                    "customer_id_backfilled_at_day17": now,
                }},
            )
            backfilled += 1

    print(f"✅ 完成")
    print(f"   - 新建客户档案: {new_count} 个")
    print(f"   - 匹配现有档案: {existing_count} 个")
    print(f"   - 回填 customer_id: {backfilled} 条 showing_request")
    print()
    print("[VERIFY] 验收:进客户 Tab,确认老客户出现;进申请页选客户,历史协作客户可选。")


def main():
    parser = argparse.ArgumentParser(description="Day 17 · 历史'无 customer_id'协作回填")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="真执行回填(默认 dry-run 只预览)",
    )
    args = parser.parse_args()

    print("=" * 60)
    print("MLS Day 17 数据迁移:历史'无 customer_id'协作回填")
    print("=" * 60)
    print()

    groups = find_backfill_groups()

    if args.apply:
        apply_backfill(groups)
    else:
        preview(groups)


if __name__ == "__main__":
    main()
