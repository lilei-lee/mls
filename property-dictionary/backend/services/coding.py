"""HMAC 算码模块 — 根据物理身份六字段生成 12 位 property_code"""
import hmac
import hashlib
import base64
from bson import ObjectId
from config import DICT_SECRET_KEY


def _normalize(value) -> str:
    if isinstance(value, ObjectId):
        return str(value)
    return str(value).strip()


def generate_property_code(
    city_id,
    district_id,
    community_id,
    building: str,
    unit: str,
    room_no: str,
) -> str:
    parts = [
        _normalize(city_id),
        _normalize(district_id),
        _normalize(community_id),
        _normalize(building),
        _normalize(unit),
        _normalize(room_no),
    ]
    message = "|".join(parts).encode("utf-8")
    secret = DICT_SECRET_KEY.encode("utf-8")

    digest = hmac.new(secret, message, hashlib.sha256).digest()
    code_b32 = base64.b32encode(digest[:8]).decode("ascii")
    return code_b32[:12]


def verify_property_code(
    code: str,
    city_id, district_id, community_id, building, unit, room_no,
) -> bool:
    expected = generate_property_code(
        city_id, district_id, community_id, building, unit, room_no
    )
    return hmac.compare_digest(code, expected)
