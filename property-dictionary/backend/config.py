"""Property Dictionary Service — 配置中心"""
import json
import os
from dotenv import load_dotenv

load_dotenv()

DICT_PORT = int(os.getenv("DICT_PORT", "8001"))
DICT_MONGO_URL = os.getenv("DICT_MONGO_URL", "mongodb://localhost:27017")
DICT_MONGO_DB = os.getenv("DICT_MONGO_DB", "property_dict")
DICT_SECRET_KEY = os.getenv("DICT_SECRET_KEY", "CHANGE_ME_DEV")


def _load_api_keys() -> dict:
    """从 .env 加载 API Keys,返回 {key_str: metadata_dict} 字典。"""
    json_str = os.getenv("DICT_API_KEYS_JSON", "").strip()
    if json_str:
        try:
            arr = json.loads(json_str)
            return {
                item["key"]: {
                    "owner": item.get("owner", "unknown"),
                    "permissions": item.get("permissions", []),
                    "city_scope": item.get("city_scope", "all"),
                    "active": item.get("active", True),
                }
                for item in arr if "key" in item
            }
        except (json.JSONDecodeError, TypeError, KeyError) as e:
            print(f"[Property Dictionary] WARNING: DICT_API_KEYS_JSON parse failed: {e}")
            return {}

    legacy = os.getenv("DICT_API_KEYS", "").strip()
    if legacy:
        print(
            "[Property Dictionary] DEPRECATION: DICT_API_KEYS is legacy, "
            "use DICT_API_KEYS_JSON for full multi-tenant support."
        )
        return {
            k.strip(): {
                "owner": "legacy", "permissions": ["read:all", "write:all"],
                "city_scope": "all", "active": True,
            }
            for k in legacy.split(",") if k.strip()
        }
    return {}


DICT_API_KEYS = _load_api_keys()
