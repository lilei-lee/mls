"""
MLS Day 15 · 数据迁移脚本:1:N 带看重构

背景
----
Day 14 之前,"直接带看"(create_direct_showing)每次都新建一条 auto_approved 的
showing_request,导致 DB 出现"同房同 BA 同客户多条申请"(图证:华新园 1-8-608 两条)。

Day 15 重构后,新数据不会再产生重复;本脚本清理历史脏数据。

归并规则
--------
- 分组键:(listing_id, buyer_agent_id, customer_key)
  · customer_key 优先用 customer_id;没有则用 (customer_surname, customer_gender)
- 保留每组里 created_at 最早的一条(协作起点)
- 后续重复条下挂的 showings 全部 reparent 到最早 req 的 _id
- 后续重复条本身改 status = "merged_into_prior" + 加字段 merged_into_request_id
  (留痕不删,与项目"重要历史不删"原则一致)

只归并 status in (approved, auto_approved, pending) 的 req。
rejected / expired / merged_into_prior 不参与(它们已经是终态或已归并)。

用法
----
预览(默认):
    python migrate_collab_1n.py

真改:
    python migrate_collab_1n.py --apply

(真改前会自动 dump 一份 showing_requests_backup_day15 备份)
"""

import argparse
import sys
from collections import defaultdict
from datetime import datetime

from database import db


# 参与归并的 status(只动"活跃协作")
ACTIVE_STATUSES = ("approved", "auto_approved", "pending")


def make_customer_key(req: dict) -> tuple:
    """生成客户分组键:有 customer_id 用它,否则退回 (surname, gender)"""
    cid = req.get("customer_id")
    if cid:
        return ("by_id", str(cid))
    return (
        "by_profile",
        req.get("customer_surname", "") or "",
        req.get("customer_gender", "") or "",
    )


def find_duplicate_groups() -> list[dict]:
    """扫描所有 showing_requests,按分组键聚合,返回 size > 1 的组

    每个返回元素:
      {
        "key": (listing_id, buyer_agent_id, customer_key_tuple),
        "requests": [req_doc, ...]  # 按 created_at 升序
      }
    """
    cursor = db["showing_requests"].find(
        {"status": {"$in": list(ACTIVE_STATUSES)}}
    )

    groups: dict[tuple, list] = defaultdict(list)
    for req in cursor:
        key = (
            req.get("listing_id"),
            req.get("buyer_agent_id"),
            make_customer_key(req),
        )
        # listing_id / buyer_agent_id 缺失的脏数据跳过(理论上不应有)
        if not key[0] or not key[1]:
            continue
        groups[key].append(req)

    duplicates = []
    for key, reqs in groups.items():
        if len(reqs) > 1:
            reqs.sort(key=lambda r: r.get("created_at") or datetime.min)
            duplicates.append({"key": key, "requests": reqs})

    return duplicates


def format_request_brief(req: dict) -> str:
    """打印用的简要描述"""
    snap = req.get("listing_snapshot", {})
    addr = (
        f"{snap.get('community', '?')}"
        f" {snap.get('building', '')}-{snap.get('unit', '')}-{snap.get('room_no', '')}"
    )
    surname = req.get("customer_surname", "?")
    gender_label = {"male": "先生", "female": "女士"}.get(
        req.get("customer_gender", ""), ""
    )
    created = req.get("created_at")
    created_str = created.strftime("%Y-%m-%d %H:%M") if created else "?"
    return (
        f"  req={str(req['_id'])[:8]}.. "
        f"{addr} 客户={surname}{gender_label} "
        f"status={req.get('status')} created={created_str}"
    )


def preview(duplicates: list[dict]) -> None:
    """打印归并预览"""
    if not duplicates:
        print("✅ 没有需要归并的重复申请,DB 已经干净。")
        return

    print(f"⚠️  发现 {len(duplicates)} 组重复申请,将归并:\n")
    total_extra_reqs = 0
    total_reparent_showings = 0

    for i, group in enumerate(duplicates, 1):
        reqs = group["requests"]
        keep = reqs[0]
        merge_list = reqs[1:]

        print(f"--- 组 {i} (共 {len(reqs)} 条申请) ---")
        print(f"  ✅ 保留(协作起点):")
        print(format_request_brief(keep))
        print(f"  🔀 归并到上面:")

        for r in merge_list:
            print(format_request_brief(r))
            # 这条 req 下挂多少 showings
            n = db["showings"].count_documents({"showing_request_id": r["_id"]})
            print(f"      └─ 下挂 {n} 条带看,将 reparent 到保留条")
            total_reparent_showings += n
            total_extra_reqs += 1
        print()

    print(f"📊 总结:")
    print(f"  - 待归并申请数(标 merged_into_prior): {total_extra_reqs}")
    print(f"  - 待 reparent 带看数: {total_reparent_showings}")
    print()
    print("ℹ️  这是 dry-run,未做任何修改。加 --apply 真改。")


def backup_collection() -> str:
    """用 $out 把 showing_requests 整体 dump 到备份集合"""
    backup_name = f"showing_requests_backup_day15"
    pipeline = [{"$out": backup_name}]
    list(db["showing_requests"].aggregate(pipeline))
    count = db[backup_name].count_documents({})
    return f"已备份 {count} 条到集合 `{backup_name}`"


def apply_merge(duplicates: list[dict]) -> None:
    """真执行归并"""
    if not duplicates:
        print("✅ 没有需要归并的,直接退出。")
        return

    print("🔒 第一步:备份原始 showing_requests 集合")
    print(f"   {backup_collection()}\n")

    now = datetime.now()
    merged_count = 0
    reparent_count = 0

    for group in duplicates:
        reqs = group["requests"]
        keep_id = reqs[0]["_id"]
        merge_list = reqs[1:]

        for r in merge_list:
            old_id = r["_id"]

            # 1. reparent showings
            res = db["showings"].update_many(
                {"showing_request_id": old_id},
                {"$set": {
                    "showing_request_id": keep_id,
                    "reparented_at_day15": now,
                    "original_request_id": old_id,
                }},
            )
            reparent_count += res.modified_count

            # 2. 标记原 req 为已归并(不删)
            db["showing_requests"].update_one(
                {"_id": old_id},
                {"$set": {
                    "status": "merged_into_prior",
                    "merged_into_request_id": keep_id,
                    "merged_at_day15": now,
                    "updated_at": now,
                }},
            )
            merged_count += 1

    print(f"✅ 完成")
    print(f"   - 归并申请: {merged_count} 条 (status=merged_into_prior)")
    print(f"   - 重挂带看: {reparent_count} 条")
    print()
    print("🔍 验收:进协作 Tab,确认重复卡片消失;同房同客户只剩 1 条。")


def main():
    parser = argparse.ArgumentParser(description="Day 15 · 1:N 带看数据迁移")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="真执行归并(默认 dry-run 只预览)",
    )
    args = parser.parse_args()

    print("=" * 60)
    print("MLS Day 15 数据迁移:1:N 带看 · 归并重复申请")
    print("=" * 60)
    print()

    duplicates = find_duplicate_groups()

    if args.apply:
        apply_merge(duplicates)
    else:
        preview(duplicates)


if __name__ == "__main__":
    main()