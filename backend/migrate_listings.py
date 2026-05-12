"""
一次性迁移脚本
给已有的老数据补上 V2 新增的字段:district、rooms、bathrooms

用法:
    cd C:\\projects\\mls\\backend
    venv\\Scripts\\activate
    python migrate_listings.py
"""
import re
from database import db

listings_collection = db["listings"]


def parse_layout(layout_str: str) -> tuple[int, int, int]:
    """
    把 '2室1厅1卫' 这种字符串解析成 (2, 1, 1)
    兼容写法:'2室1厅'(卫默认1)、'2-1-1' 等
    解析不出来就返回 (0, 0, 0)
    """
    if not layout_str:
        return (0, 0, 0)

    # 匹配中文 "X室X厅X卫"
    m = re.match(r"^(\d+)\s*室\s*(\d+)\s*厅\s*(\d+)\s*卫", layout_str)
    if m:
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)))

    # 匹配 "X室X厅"(缺卫)
    m = re.match(r"^(\d+)\s*室\s*(\d+)\s*厅", layout_str)
    if m:
        return (int(m.group(1)), int(m.group(2)), 1)  # 默认 1 卫

    # 匹配 "X-X-X"
    m = re.match(r"^(\d+)[-_](\d+)[-_](\d+)", layout_str)
    if m:
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)))

    return (0, 0, 0)


def migrate():
    print("=" * 50)
    print("开始迁移 listings 集合...")
    print("=" * 50)

    cursor = listings_collection.find({})
    total = 0
    updated = 0
    skipped = 0

    for doc in cursor:
        total += 1
        set_fields = {}

        # 1. 补 district(旧数据默认"其他",以后用户手动改)
        if "district" not in doc:
            set_fields["district"] = "其他"

        # 2. 补 rooms/bathrooms(从 layout 解析)
        if "rooms" not in doc or "halls" not in doc or "bathrooms" not in doc:
            rooms, halls, bathrooms = parse_layout(doc.get("layout", ""))
            set_fields["rooms"] = rooms
            set_fields["bathrooms"] = bathrooms

        if set_fields:
            listings_collection.update_one(
                {"_id": doc["_id"]},
                {"$set": set_fields},
            )
            updated += 1
            print(f"  ✅ 已更新: {doc.get('community', '?')} {doc.get('building', '?')}-{doc.get('unit', '?')}-{doc.get('room_no', '?')}")
            print(f"     补充字段: {set_fields}")
        else:
            skipped += 1

    print("=" * 50)
    print(f"迁移完成")
    print(f"  总记录数: {total}")
    print(f"  已更新: {updated}")
    print(f"  跳过(已是新数据): {skipped}")
    print("=" * 50)


if __name__ == "__main__":
    migrate()