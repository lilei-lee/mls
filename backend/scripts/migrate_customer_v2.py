"""
客户状态流水迁移 V2(客户管理升级)

把旧的两态 active/closed 迁到新流水:
    active → following(跟进中)
    closed → lost(已战败,缺原因则补"历史关闭")

铁律 1:默认 dry-run(只读,列出将改什么),确认后加 --apply 真改。
apply 前自动把目标文档备份到集合 customers_backup_v2。

用法:
    cd C:\\projects\\mls\\backend
    venv\\Scripts\\activate
    python scripts\\migrate_customer_v2.py          # dry-run
    python scripts\\migrate_customer_v2.py --apply   # 真改
"""
import sys
from datetime import datetime
from database import db

STATUS_MAP = {"active": "following", "closed": "lost"}


def main(apply: bool):
    customers = db["customers"]

    print("=== 当前 status 分布 ===")
    for s in customers.distinct("status"):
        print(f"  {s!r}: {customers.count_documents({'status': s})} 条")

    targets = list(customers.find({"status": {"$in": list(STATUS_MAP)}}))
    print(f"\n=== 将迁移 {len(targets)} 条 ===")
    for d in targets:
        old = d["status"]
        new = STATUS_MAP[old]
        extra = ""
        if new == "lost" and not d.get("lost_reason"):
            extra = "  (+ lost_reason='历史关闭')"
        print(f"  {d.get('surname', '?')} [{d['_id']}]: {old} → {new}{extra}")

    if not apply:
        print("\n[DRY-RUN] 未改动任何数据。核对无误后加 --apply 执行。")
        return

    if not targets:
        print("\n没有需要迁移的数据。")
        return

    # 备份
    backup = db["customers_backup_v2"]
    backup.delete_many({})
    backup.insert_many([dict(d) for d in targets])
    print(f"\n[备份] {len(targets)} 条已存入 customers_backup_v2")

    migrated = 0
    for d in targets:
        new = STATUS_MAP[d["status"]]
        set_doc = {"status": new, "updated_at": datetime.now()}
        if new == "lost" and not d.get("lost_reason"):
            set_doc["lost_reason"] = "历史关闭"
        customers.update_one({"_id": d["_id"]}, {"$set": set_doc})
        migrated += 1

    print(f"[APPLY] 已迁移 {migrated} 条。")
    print("=== 迁移后 status 分布 ===")
    for s in customers.distinct("status"):
        print(f"  {s!r}: {customers.count_documents({'status': s})} 条")
    remaining = customers.count_documents({"status": {"$in": list(STATUS_MAP)}})
    print(f"\n校验:残留旧状态 {remaining} 条(应为 0)。"
          + (" ✅" if remaining == 0 else " ⚠️ 请检查"))


if __name__ == "__main__":
    main("--apply" in sys.argv)
