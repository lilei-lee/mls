"""Property Dictionary Service — MongoDB 连接"""
from pymongo import MongoClient
from config import DICT_MONGO_URL, DICT_MONGO_DB

client = MongoClient(DICT_MONGO_URL)
db = client[DICT_MONGO_DB]


def ping_db() -> str:
    try:
        client.admin.command("ping")
        return "ok"
    except Exception as e:
        return f"error: {repr(e)}"
