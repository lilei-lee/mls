"""
V3 前置清理:移除 properties 集合中 attribute_claims.field=halls 的历史条目

执行日期: 2026-05-12
影响范围: 10 个 property 文档, 11 条 attribute_claims
备份位置: property-dictionary/backend/halls_backup/halls_backup.json
执行结果: matched=10, modified=10, residual=0

一次性脚本,已执行完毕,留作历史档案。
"""

import sys
import os
from datetime import datetime

# 编码加固
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

print("=" * 60)
print("cleanup_halls_2026_05.py")
print()
print("此脚本已于 2026-05-12 执行完毕,不应再次运行。")
print("如需再次执行,请确认已了解其影响。")
print("=" * 60)
print()

# 路径:确保从 property-dictionary/backend 目录运行
_HERE = os.path.dirname(os.path.abspath(__file__))
_BACKEND = os.path.dirname(_HERE)
if os.getcwd() != _BACKEND:
    os.chdir(_BACKEND)

from database import db

props = db["properties"]
APPLY = "--apply" in sys.argv


def dry_run():
    """只读查询,列出现有的 halls 条目,不修改任何数据"""
    print("[DRY-RUN] 查询 attribute_claims.field=halls ...")
    total = 0
    affected = 0
    for p in props.find(
        {"attribute_claims.field": "halls"},
        {"property_code": 1, "attribute_claims": 1},
    ):
        halls = [c for c in p.get("attribute_claims", []) if c.get("field") == "halls"]
        if halls:
            affected += 1
            total += len(halls)
            print(f"  {p['property_code']}: {len(halls)} halls claim(s)")
            for h in halls:
                print(f"    value={h.get('value')}, agent_id={h.get('agent_id')}")

    print()
    print(f"[DRY-RUN] 受影响 property: {affected}, halls 条目: {total}")
    print(f"[DRY-RUN] 备份: {os.path.join(_BACKEND, 'halls_backup', 'halls_backup.json')}")
    print("[DRY-RUN] 未做任何修改。加 --apply 参数执行实际清理。")


def apply():
    """执行 $pull 删除 halls 条目"""
    print("[APPLY] 开始清理...")
    result = props.update_many(
        {"attribute_claims.field": "halls"},
        {"$pull": {"attribute_claims": {"field": "halls"}}},
    )
    print(f"[APPLY] matched_count: {result.matched_count}")
    print(f"[APPLY] modified_count: {result.modified_count}")
    return result


def verify():
    """验证清理结果"""
    print("[VERIFY] 验证清理结果...")
    count = props.count_documents({"attribute_claims.field": "halls"})
    print(f"[VERIFY] attribute_claims.field=halls 残留: {count}")

    sample = props.find_one({})
    if sample:
        claims = sample.get("attribute_claims", [])
        fields = [c.get("field") for c in claims]
        print(f"[VERIFY] 抽样 {sample['property_code']}: {len(claims)} claims, fields={fields}")
        print(f"[VERIFY] halls 在 claims 中: {'halls' in fields}")

    print(f"[VERIFY] 验证{'通过' if count == 0 else '未通过!'}")


def main():
    if APPLY:
        answer = input("确认要再次执行清理? [y/N]: ").strip().lower()
        if answer != "y":
            print("已取消。")
            return
        apply()
        verify()
        print("[DONE] 清理完成。")
    else:
        dry_run()
        print()
        print("提示: 加 --apply 参数执行实际清理。")
        print("示例: python scripts/cleanup_halls_2026_05.py --apply")


if __name__ == "__main__":
    main()
