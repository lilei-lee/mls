"""cities + districts 索引初始化(幂等)"""
from pymongo import ASCENDING
from database import db

cities_collection = db["cities"]
districts_collection = db["districts"]


def ensure_dictionary_indexes() -> dict:
    cities_collection.create_index(
        [("name", ASCENDING)], unique=True, name="cities_name_unique"
    )
    districts_collection.create_index(
        [("city_id", ASCENDING), ("name", ASCENDING)],
        unique=True,
        name="districts_city_name_unique",
    )
    return {
        "cities": [idx["name"] for idx in cities_collection.list_indexes()],
        "districts": [idx["name"] for idx in districts_collection.list_indexes()],
    }
