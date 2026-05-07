"""一次性预填:张家口 + 17 个区县(幂等,可重复运行)"""
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import db
from models.dictionaries import ensure_dictionary_indexes

CITY_DISTRICTS = [
    "桥东区", "桥西区", "经开区", "万全区", "宣化区", "下花园区", "崇礼区",
    "张北县", "康保县", "沽源县", "尚义县", "蔚县",
    "阳原县", "怀安县", "怀来县", "涿鹿县", "赤城县",
]


def seed():
    # 1. indexes
    idx_info = ensure_dictionary_indexes()
    print("Indexes ensured:")
    print(f"  cities: {idx_info['cities']}")
    print(f"  districts: {idx_info['districts']}")
    print()

    # 2. city
    zjk = db["cities"].find_one({"name": "张家口"})
    if zjk is None:
        result = db["cities"].insert_one({
            "name": "张家口",
            "code": "ZJK",
            "created_at": datetime.now(),
        })
        zjk = db["cities"].find_one({"_id": result.inserted_id})
        print(f"City inserted: 张家口 (ZJK)")
    else:
        print("City existed: 张家口")
    zjk_id = zjk["_id"]

    # 3. districts
    inserted = 0
    existed = 0
    for name in CITY_DISTRICTS:
        existing = db["districts"].find_one({"city_id": zjk_id, "name": name})
        if existing:
            print(f"  [existed] {name}")
            existed += 1
        else:
            db["districts"].insert_one({
                "city_id": zjk_id,
                "name": name,
                "created_at": datetime.now(),
            })
            print(f"  [inserted] {name}")
            inserted += 1

    cities_total = db["cities"].count_documents({})
    districts_total = db["districts"].count_documents({})
    print()
    print(f"Cities total={cities_total}, districts total={districts_total}, "
          f"inserted_now={inserted}, existed={existed}")


if __name__ == "__main__":
    seed()
