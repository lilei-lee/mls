"""V2.2 #2: 旧 orientation 值迁移到 4 枚举(朝东/朝西/朝南/朝北)

用法:
  cd C:\projects\mls\backend
  venv\Scripts\activate
  python scripts\migrate_orientation_v22.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database import db

MAPPING = {
    "南": "朝南", "南向": "朝南", "南北": "朝南", "南北通透": "朝南",
    "北": "朝北", "北向": "朝北",
    "东": "朝东", "东向": "朝东",
    "西": "朝西", "西向": "朝西",
}

# Print current state
docs = list(db["listings"].find({}, {"orientation": 1, "community": 1}))
print(f"Total listings: {len(docs)}")
print("Current orientations:")
from collections import Counter
c = Counter(d.get("orientation", "") for d in docs)
for k, v in c.most_common():
    print(f"  {k!r}: {v}")

# Apply migration
changed = 0
for d in docs:
    old = d.get("orientation", "")
    new = MAPPING.get(old)
    if new and new != old:
        db["listings"].update_one({"_id": d["_id"]}, {"$set": {"orientation": new}})
        changed += 1
        print(f"  [{old!r} → {new!r}] {d.get('community','?')}")

print(f"\nChanged: {changed}")
if changed == 0:
    print("(all orientations already use new enum)")
