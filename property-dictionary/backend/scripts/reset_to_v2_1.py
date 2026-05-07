"""数据清空脚本 — 重置辞典所有业务集合,预填张家口 17 区县"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime
from database import db
from models.dictionaries import ensure_dictionary_indexes
from models.community import ensure_community_indexes
from models.property import ensure_property_indexes
from models.audit_log import ensure_audit_log_indexes

COLLECTIONS_TO_RESET = [
    "cities", "districts", "communities", "properties",
    "property_discrepancies", "audit_logs",
]

ZJK_DISTRICTS = [
    "桥东区", "桥西区", "经开区", "万全区", "宣化区", "下花园区", "崇礼区",
    "张北县", "康保县", "沽源县", "尚义县", "蔚县",
    "阳原县", "怀安县", "怀来县", "涿鹿县", "赤城县",
]


def confirm_reset() -> bool:
    print("=" * 70)
    print("WARNING: this script will drop ALL dictionary data.")
    print("=" * 70)
    print()
    print("Collections affected:")
    for c in COLLECTIONS_TO_RESET:
        try:
            count = db[c].count_documents({})
            print(f"  - {c} (current: {count} docs)")
        except Exception:
            print(f"  - {c} (current: ?)")
    print()
    print("After reset:")
    print("  1. Rebuild all indexes")
    print("  2. Re-seed Zhangjiakou: 1 city + 17 districts")
    print()
    print("This operation is IRREVERSIBLE.")
    print()
    user_input = input('Type "RESET CONFIRM" to proceed (anything else cancels): ')
    return user_input == "RESET CONFIRM"


def drop_all_collections():
    print("\n[1/4] Dropping collections...")
    for name in COLLECTIONS_TO_RESET:
        try:
            db[name].drop()
            print(f"  OK dropped {name}")
        except Exception as e:
            print(f"  WARN {name} drop error: {e}")


def rebuild_indexes():
    print("\n[2/4] Rebuilding indexes...")
    d = ensure_dictionary_indexes()
    print(f"  OK cities + districts: {sum(len(v) for v in d.values())} indexes")
    c = ensure_community_indexes()
    print(f"  OK communities: {len(c)} indexes")
    p = ensure_property_indexes()
    print(f"  OK properties: {len(p['properties'])} indexes")
    print(f"  OK property_discrepancies: {len(p['discrepancies'])} indexes")
    a = ensure_audit_log_indexes()
    print(f"  OK audit_logs: {len(a)} indexes")


def seed_zhangjiakou():
    print("\n[3/4] Seeding Zhangjiakou + 17 districts...")
    now = datetime.now()
    db["cities"].insert_one({"name": "张家口", "code": "ZJK", "created_at": now})
    zjk = db["cities"].find_one({"name": "张家口"})
    print(f"  OK city: 张家口 (_id={zjk['_id']})")

    docs = [{"city_id": zjk["_id"], "name": name, "created_at": now} for name in ZJK_DISTRICTS]
    db["districts"].insert_many(docs)
    print(f"  OK {len(docs)} districts inserted")


def verify_state():
    print("\n[4/4] Verifying state...")
    expected = {
        "cities": 1, "districts": 17, "communities": 0,
        "properties": 0, "property_discrepancies": 0, "audit_logs": 0,
    }
    all_ok = True
    for name, exp in expected.items():
        actual = db[name].count_documents({})
        ok = actual == exp
        print(f"  {'OK' if ok else 'FAIL'} {name}: {actual} (expected {exp})")
        if not ok: all_ok = False
    return all_ok


def main():
    if not confirm_reset():
        print("\nCancelled. No changes made.")
        sys.exit(0)
    drop_all_collections()
    rebuild_indexes()
    seed_zhangjiakou()
    if verify_state():
        print("\n[DONE] Reset complete. Dictionary data restored to initial state.")
        sys.exit(0)
    else:
        print("\n[WARN] Reset complete but state verification failed. Manual check required.")
        sys.exit(1)


if __name__ == "__main__":
    main()
