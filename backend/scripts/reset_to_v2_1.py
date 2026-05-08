"""V2.1 全清脚本 — MLS 侧,幂等可重复执行"""
import sys, os, argparse
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import db

# 清空集合(按 V2.1 #15 启动策略)
COLLECTIONS_TO_RESET = [
    "agents",
    "customers",
    "listings",
    "showing_requests",
    "showings",
    "transactions",
    "settlements",
    "pending_dict_sinks",
]

# 保留集合(不碰):
# - communities(MLS 缓存的,如 communities 集合在 mls 库中)
# - *_backup_*(历史快照)


def dry_run():
    """只读模式:列出每个集合的文档数,不清空"""
    print("=== DRY RUN ===\n")
    total = 0
    for name in COLLECTIONS_TO_RESET:
        try:
            cnt = db[name].count_documents({})
            print(f"  {name}: {cnt} docs")
            total += cnt
        except Exception:
            print(f"  {name}: (collection does not exist)")
    print(f"\n  Total: {total} docs would be deleted")
    print("\n[DRY RUN] No data modified.")


def reset():
    """清空所有业务集合"""
    confirm = input(
        "WARNING: This will DELETE ALL business data in the MLS database.\n"
        "Type \"RESET CONFIRM\" to proceed (anything else cancels): "
    )
    if confirm != "RESET CONFIRM":
        print("Cancelled. No data modified.")
        sys.exit(0)

    for name in COLLECTIONS_TO_RESET:
        try:
            result = db[name].delete_many({})
            print(f"  {name}: {result.deleted_count} docs deleted")
        except Exception as e:
            print(f"  {name}: error - {e}")

    print("\n[DONE] Reset complete. All business data cleared.")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="MLS V2.1 reset script")
    p.add_argument("--dry-run", action="store_true", help="Report what would be deleted, without deleting")
    p.add_argument("--execute", action="store_true", help="Actually execute the reset (REQUIRES typing RESET CONFIRM)")
    args = p.parse_args()

    if args.dry_run:
        dry_run()
    elif args.execute:
        reset()
    else:
        print("Usage: python scripts/reset_to_v2_1.py --dry-run | --execute")
        sys.exit(1)
