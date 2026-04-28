"""
MLS Day 17 · 回填校验脚本

在 apply 之后运行,验证回填结果正确性。

用法:
    python verify_customer_backfill.py

校验项:
  [1] 7 条 showing_requests 全部 customer_id 非空
  [2] customer_id set 去重后得 5 个不同值(组内同一,组间不同)
  [3] 第 1 组 2 条 customer_id 相等, 第 4 组 2 条 customer_id 相等
      (含 rejected(69e92030) 和 approved(69e9209f) 必须等同)
  [4] 5 个 customer 档案的 (owner_agent_id, surname, gender) 与期望表一致
      (用 _id 反查,不用三字段 find_one)
  [5] showing_requests_backup_day17 和 customers_backup_day17 都存在且非空
  [6] customers_backup_day17 条数 + 5 = customers 当前条数
"""

from database import db
from bson import ObjectId

# ===== 期望值表(从 dry-run 输出提取) =====
# 每组: [req_id_hex, ...], 期望 (owner_agent_id_hex, surname, gender)

GROUPS = {
    "组1_华新园1-8-608_王先生": {
        "req_ids": [
            "69e74bbd3a977d951b6e3b2a",  # approved
            "69e7534f3a977d951b6e3b2c",  # merged_into_prior
        ],
        "expected": ("69e45ec6e52ec020aa924065", "王", "male"),
    },
    "组2_碧桂园天玺1-2-508_王先生": {
        "req_ids": [
            "69e5a5b731ec4072c595d4b1",  # approved
        ],
        "expected": ("69e591f445422a0cfdbd0826", "王", "male"),
    },
    "组3_华新园3-2-502_刘先生": {
        "req_ids": [
            "69e6303c4ab0914b8d8f1514",  # approved
        ],
        "expected": ("69e59f89bf03b3f95048b405", "刘", "male"),
    },
    "组4_碧桂园天玺1-2-508_张先生": {
        "req_ids": [
            "69e92030180d4eb3ddd26c5a",  # rejected
            "69e9209f180d4eb3ddd26c5b",  # approved
        ],
        "expected": ("69e59f89bf03b3f95048b405", "张", "male"),
    },
    "组5_华新园3-2-502_陈女士": {
        "req_ids": [
            "69e5aa5331ec4072c595d4b2",  # approved
        ],
        "expected": ("69e59f89bf03b3f95048b405", "陈", "female"),
    },
}


def verify():
    import sys
    passed = 0
    failed = 0

    def report(ok, msg):
        nonlocal passed, failed
        tag = "PASS" if ok else "FAIL"
        if not ok:
            failed += 1
        else:
            passed += 1
        sys.stdout.write(f"  [{tag}] {msg}\n")

    # ===== [1] 7 条 showing_requests 全部 customer_id 非空 =====
    print("[1] 验证 7 条历史申请 customer_id 全部非空")
    all_customer_ids = {}  # req_id_hex -> customer_id_hex
    for group_name, group_data in GROUPS.items():
        for req_hex in group_data["req_ids"]:
            req_oid = ObjectId(req_hex)
            r = db["showing_requests"].find_one({"_id": req_oid})
            if not r:
                report(False, f"req={req_hex[:8]} 记录不存在!")
                continue
            cid = r.get("customer_id")
            if cid:
                all_customer_ids[req_hex] = str(cid)
                report(True, f"req={req_hex[:8]}  customer_id={str(cid)[:8]}")
            else:
                report(False, f"req={req_hex[:8]}  customer_id=NULL!")
    print()

    # ===== [2] customer_id set 去重后得 5 个不同值 =====
    print("[2] 验证 customer_id 去重后得 5 个不同值")
    unique_cids = set(all_customer_ids.values())
    report(len(unique_cids) == 5, f"去重得 {len(unique_cids)} 个(期望 5)")
    if len(unique_cids) == 5:
        for cid in sorted(unique_cids):
            sys.stdout.write(f"      {cid[:8]}..\n")
    print()

    # ===== [3] 组内 customer_id 相等(第 1 组 2 条,第 4 组 2 条) =====
    print("[3] 验证组内 customer_id 一致性")
    for group_name, group_data in GROUPS.items():
        req_ids = group_data["req_ids"]
        if len(req_ids) < 2:
            report(True, f"{group_name}: 仅 1 条申请,跳过组内一致性检查")
            continue
        cids = [all_customer_ids.get(rid) for rid in req_ids]
        all_equal = len(set(cids)) == 1 and cids[0] is not None
        report(all_equal, f"{group_name}: {len(req_ids)} 条 customer_id 一致")
        if not all_equal:
            for rid, cid in zip(req_ids, cids):
                sys.stdout.write(f"      req={rid[:8]}  customer_id={cid or 'NULL'}\n")

    # 特检:第 4 组 rejected vs approved
    rejected_hex = "69e92030180d4eb3ddd26c5a"
    approved_hex = "69e9209f180d4eb3ddd26c5b"
    cid_rej = all_customer_ids.get(rejected_hex)
    cid_app = all_customer_ids.get(approved_hex)
    if cid_rej and cid_app and cid_rej == cid_app:
        report(True, f"第 4 组 rejected({rejected_hex[:8]}) = approved({approved_hex[:8]})")
    else:
        report(False, f"第 4 组 rejected({rejected_hex[:8]} {cid_rej}) != approved({approved_hex[:8]} {cid_app})")
    print()

    # ===== [4] 5 个 customer 档案与期望表一致 =====
    print("[4] 验证 5 个 customer 档案(owner_agent_id, surname, gender)")
    for group_name, group_data in GROUPS.items():
        # 取该组任意一条的 customer_id (组内一致已验证)
        cid_hex = all_customer_ids.get(group_data["req_ids"][0])
        if not cid_hex:
            report(False, f"{group_name}: customer_id 为空,无法反查档案")
            continue
        expected_ba, expected_surname, expected_gender = group_data["expected"]
        cust = db["customers"].find_one({"_id": ObjectId(cid_hex)})
        if not cust:
            report(False, f"{group_name}: _id={cid_hex[:8]} 的 customer 不存在")
            continue
        ba_match = str(cust.get("owner_agent_id", "")) == expected_ba
        surname_match = cust.get("surname") == expected_surname
        gender_match = cust.get("gender") == expected_gender
        all_match = ba_match and surname_match and gender_match
        report(all_match, f"{group_name}: {str(cust['_id'])[:8]}.. BA={'OK' if ba_match else 'FAIL'} 姓氏={'OK' if surname_match else 'FAIL'} 性别={'OK' if gender_match else 'FAIL'}")
    print()

    # ===== [5] 备份集合存在且非空 =====
    print("[5] 验证备份集合存在且非空")
    for col_name in ["showing_requests_backup_day17", "customers_backup_day17"]:
        count = db[col_name].count_documents({})
        report(count > 0, f"{col_name}: {count} 条")
    print()

    # ===== [6] customers 备份条数 + 5 = 当前条数 =====
    print("[6] 验证 customers 当前条数 = 备份条数 + 5")
    backup_count = db["customers_backup_day17"].count_documents({})
    current_count = db["customers"].count_documents({})
    expected_current = backup_count + 5
    report(current_count == expected_current, f"备份({backup_count}) + 5 = {expected_current}, 当前={current_count}")
    print()

    # ===== 总结 =====
    print(f"[SUMMARY] 通过: {passed}  失败: {failed}")
    if failed == 0:
        print("  全部校验通过,回填成功!")
    else:
        print(f"  {failed} 项校验失败,请检查!")
    print()
    return failed == 0


if __name__ == "__main__":
    verify()
