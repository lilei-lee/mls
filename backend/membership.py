"""会员费机制 — 状态判定 + 后台开通/续期 + 展示。

设计(磊 2026-06-14 决策):
- 全局开关 config.MEMBERSHIP_ENFORCED:
    false = 免费试用期,人人完整可用,不拦任何写操作(默认)
    true  = 收费期,到期日在未来 = 有效会员;否则 = 只读(写操作被中间件拦 402)
- agent.membership_expires_at(datetime | None):会员到期日
- 不设固定试用天数(MEMBERSHIP_TRIAL_DAYS=0),完全靠开关 + 后台手动开通
- 后台控制:scripts/grant_membership.py 按手机号设/续到期日

config 值用 `config.MEMBERSHIP_ENFORCED` 动态读取(不 from import),
这样测试可 monkeypatch、运行时改环境变量也即时生效。
"""
from datetime import datetime, timedelta
from typing import Optional

import config
from database import db


def is_member_active(agent: dict) -> bool:
    """是否拥有完整(写)权限。开关关闭时永远 True(免费期)。"""
    if not config.MEMBERSHIP_ENFORCED:
        return True
    exp = agent.get("membership_expires_at")
    return isinstance(exp, datetime) and exp > datetime.now()


def membership_info(agent: dict) -> dict:
    """给 /me 和 /membership 用的会员状态。"""
    exp = agent.get("membership_expires_at")
    active = is_member_active(agent)
    days_left = None
    if isinstance(exp, datetime):
        days_left = max((exp - datetime.now()).days, 0)
    return {
        "enforced": config.MEMBERSHIP_ENFORCED,
        "active": active,
        "read_only": config.MEMBERSHIP_ENFORCED and not active,
        "expires_at": exp.strftime("%Y-%m-%d") if isinstance(exp, datetime) else None,
        "days_left": days_left,
    }


def initial_membership_expiry() -> Optional[datetime]:
    """注册时的初始到期日(TRIAL_DAYS=0 时为 None,完全靠后台开通)。"""
    if config.MEMBERSHIP_TRIAL_DAYS > 0:
        return datetime.now() + timedelta(days=config.MEMBERSHIP_TRIAL_DAYS)
    return None


def set_membership_by_phone(phone: str, expires_at: datetime) -> dict:
    """后台:按手机号设/续会员到期日。"""
    agent = db["agents"].find_one({"phone": phone})
    if not agent:
        return {"matched": False}
    db["agents"].update_one(
        {"_id": agent["_id"]},
        {"$set": {"membership_expires_at": expires_at, "updated_at": datetime.now()}},
    )
    return {
        "matched": True,
        "agent_name": agent.get("name", ""),
        "expires_at": expires_at.strftime("%Y-%m-%d"),
    }
