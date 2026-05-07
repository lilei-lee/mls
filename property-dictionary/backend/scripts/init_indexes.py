"""一次性脚本:初始化所有集合索引(幂等,可重复执行)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.dictionaries import ensure_dictionary_indexes
from models.community import ensure_community_indexes
from models.property import ensure_property_indexes
from models.audit_log import ensure_audit_log_indexes


def main():
    print("=== Initializing all dictionary indexes ===\n")

    print("[1/4] dictionaries (cities + districts)")
    d = ensure_dictionary_indexes()
    print(f"      cities: {d['cities']}")
    print(f"      districts: {d['districts']}")

    print("\n[2/4] communities")
    c = ensure_community_indexes()
    print(f"      indexes: {c}")

    print("\n[3/4] properties + discrepancies")
    p = ensure_property_indexes()
    print(f"      properties: {p['properties']}")
    print(f"      discrepancies: {p['discrepancies']}")

    print("\n[4/4] audit_logs")
    a = ensure_audit_log_indexes()
    print(f"      indexes: {a}")

    print("\n[DONE] All indexes ensured.")


if __name__ == "__main__":
    main()
