"""V2.2 #1: 协作状态 helper — 判断 viewer 是否有权看 listing 完整字段"""

from bson import ObjectId
from database import db

_UNLOCKED_REQUEST_STATUSES = {"approved", "auto_approved", "in_progress", "completed"}


def is_collaboration_unlocked(viewer_agent_id, listing_id: str) -> bool:
    """返 True 如果 viewer 和 listing 有有效协作链。

    LA 看自己的 listing → True
    BA 有 approved/in_progress/completed 的 showing_request 链 → True
    其他 → False
    """
    try:
        listing_oid = ObjectId(listing_id)
    except Exception:
        return False

    listing = db["listings"].find_one({"_id": listing_oid}, {"owner_agent_id": 1})
    if not listing:
        return False

    viewer_id = viewer_agent_id
    if isinstance(viewer_id, str):
        try:
            viewer_id = ObjectId(viewer_id)
        except Exception:
            return False

    # LA 看自己
    if viewer_id == listing["owner_agent_id"]:
        return True

    # BA:查是否有有效 showing_request 链
    req = db["showing_requests"].find_one(
        {
            "listing_id": listing_oid,
            "buyer_agent_id": viewer_id,
            "status": {"$in": list(_UNLOCKED_REQUEST_STATUSES)},
        },
        {"_id": 1},
    )
    return req is not None
