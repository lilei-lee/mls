"""Property Dictionary Service — 配置中心"""
import os
from dotenv import load_dotenv

load_dotenv()

DICT_PORT = int(os.getenv("DICT_PORT", "8001"))
DICT_MONGO_URL = os.getenv("DICT_MONGO_URL", "mongodb://localhost:27017")
DICT_MONGO_DB = os.getenv("DICT_MONGO_DB", "property_dict")
DICT_SECRET_KEY = os.getenv("DICT_SECRET_KEY", "CHANGE_ME_DEV")

_raw_keys = os.getenv("DICT_API_KEYS", "")
DICT_API_KEYS = [k.strip() for k in _raw_keys.split(",") if k.strip()]
