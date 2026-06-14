"""系统配置(模块六 §8)— 运营参数的 key-value 存储 + 读取。

只收录"代码里真有强制点、改了立刻生效"的运营参数。设计稿 §8 其余二十多项
多数对应尚未实现的功能(回退/驳回冻结/定金监控等),存进来是摆设,故不收录,
待对应功能落地再加。

存储:system_config 集合,_id = 配置 key,value = 值。读取带默认值兜底。
"""
from datetime import datetime

from database import db

# 收录的可配置项(均为整数;label/note 供后台展示)
CONFIG_SPEC = [
    {"key": "showing_request_expire_days", "label": "带客申请有效期(天)", "default": 7,
     "note": "超过此天数未处理的 pending 申请自动过期(scheduler 每日 03:00)"},
    {"key": "listing_max_photos", "label": "房源照片上限(张)", "default": 6,
     "note": "录入房源最多上传的照片张数"},
    {"key": "password_max_fails", "label": "密码错误锁定次数", "default": 5,
     "note": "同手机号连续输错多少次锁定登录"},
    {"key": "password_lock_minutes", "label": "密码锁定时长(分钟)", "default": 15,
     "note": "触发锁定后的持续时间"},
    {"key": "deposit_watch_days", "label": "定金异常监控窗口(天)", "default": 30,
     "note": "统计此窗口内定金标记/回退次数,超 2 次在'定金监控'标红"},
]

_DEFAULTS = {c["key"]: c["default"] for c in CONFIG_SPEC}


def get_config(key: str, default=None):
    """读配置;无记录时回退到 CONFIG_SPEC 默认值,再回退到传入 default。"""
    doc = db["system_config"].find_one({"_id": key})
    if doc is not None:
        return doc["value"]
    return _DEFAULTS.get(key, default)


def set_config(key: str, value) -> None:
    db["system_config"].update_one(
        {"_id": key},
        {"$set": {"value": value, "updated_at": datetime.now()}},
        upsert=True,
    )
