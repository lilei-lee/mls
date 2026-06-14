"""Web 管理后台 — 多管理员账号 + 角色权限(RBAC)。

商用后台不能是单一 admin。这里给出:
- admin_users 集合:多管理员账号(bcrypt 存密码),每人一个角色
- 角色 → 权限(可访问的功能区)矩阵
- 种子超级管理员引导(从 config.ADMIN_USERNAME/ADMIN_PASSWORD 落库,只在空库时)
- 登录日志 admin_login_log + 异常(陌生 IP)标记
- 鉴权/权限判定 helper

权限按"功能区(section)"粒度,与左侧导航一一对应,够商用且不过度设计。
"""
from datetime import datetime
from typing import Optional

from bson import ObjectId

from database import db
from auth import hash_password, verify_password
from config import ADMIN_USERNAME, ADMIN_PASSWORD

admin_users_collection = db["admin_users"]
admin_login_log_collection = db["admin_login_log"]


# ── 功能区(导航 + 权限粒度) ──
# (key, 中文名, 导航 URL)
SECTIONS = [
    ("dashboard", "数据看板", "/admin/"),
    ("agents", "经纪人", "/admin/agents"),
    ("listings", "房源", "/admin/listings"),
    ("transactions", "成交", "/admin/transactions"),
    ("communities", "小区库", "/admin/communities"),
    ("ownership", "归属", "/admin/ownership-changes"),
    ("disputes", "争议", "/admin/disputes"),
    ("config", "系统配置", "/admin/config"),
    ("audit", "审计日志", "/admin/audit"),
    ("admins", "管理员", "/admin/admins"),
]
ALL_PERMS = {k for k, _, _ in SECTIONS}


# ── 角色 → 权限矩阵 ──
ROLES = {
    "superadmin": {"label": "超级管理员", "perms": set(ALL_PERMS)},
    "operator": {"label": "运营", "perms": {
        "dashboard", "agents", "listings", "transactions", "communities", "ownership", "audit"}},
    "auditor": {"label": "风控审核", "perms": {
        "dashboard", "disputes", "ownership", "transactions", "audit"}},
    "support": {"label": "客服", "perms": {
        "dashboard", "agents"}},
}
ROLE_KEYS = list(ROLES.keys())


def role_label(role: str) -> str:
    return ROLES.get(role, {}).get("label", role)


def perms_for_role(role: str) -> set:
    return set(ROLES.get(role, {}).get("perms", set()))


# ── 路径 → 所需权限(require_admin 据此做功能区级鉴权) ──
# 顺序匹配,第一条命中为准;返回 None = 仅需登录、不限功能区(如图片代理)。
_PATH_PERM_RULES = [
    ("/admin/admins", "admins"),
    ("/admin/export/agents", "agents"),
    ("/admin/export/listings", "listings"),
    ("/admin/export/transactions", "transactions"),
    ("/admin/agents", "agents"),
    ("/admin/listings", "listings"),
    ("/admin/deposit-watch", "listings"),
    ("/admin/deposit-proofs", "listings"),
    ("/admin/transactions", "transactions"),
    ("/admin/community-export", "communities"),
    ("/admin/community-import", "communities"),
    ("/admin/communities", "communities"),
    ("/admin/ownership-changes", "ownership"),
    ("/admin/disputes", "disputes"),
    ("/admin/config", "config"),
    ("/admin/audit", "audit"),
    ("/admin/login-log", "admins"),
    ("/admin/photo", None),
    ("/admin/denied", None),
    ("/admin/", "dashboard"),
]


def required_perm(path: str) -> Optional[str]:
    for prefix, perm in _PATH_PERM_RULES:
        if path == prefix or path.startswith(prefix):
            return perm
    return "dashboard"


# ── 账号引导 / 认证 ──

def ensure_admin_indexes():
    admin_users_collection.create_index("username", unique=True)
    admin_login_log_collection.create_index([("username", 1), ("created_at", -1)])


def ensure_seed_admin() -> None:
    """空库时,用 config 的种子凭据建一个超级管理员。幂等。"""
    if admin_users_collection.count_documents({}) > 0:
        return
    admin_users_collection.insert_one({
        "username": ADMIN_USERNAME,
        "name": "超级管理员",
        "password_hash": hash_password(ADMIN_PASSWORD),
        "role": "superadmin",
        "status": "active",
        "created_at": datetime.now(),
        "created_by": "system",
        "last_login_at": None,
    })


def _attach_perms(doc: dict) -> dict:
    doc["perms"] = perms_for_role(doc.get("role", ""))
    doc["role_label"] = role_label(doc.get("role", ""))
    return doc


def get_admin(username: str) -> Optional[dict]:
    if not username:
        return None
    doc = admin_users_collection.find_one({"username": username})
    return _attach_perms(doc) if doc else None


def authenticate_admin(username: str, password: str) -> Optional[dict]:
    """校验账号密码 + 账号启用。成功返回带 perms 的 admin doc,否则 None。"""
    doc = admin_users_collection.find_one({"username": (username or "").strip()})
    if not doc or doc.get("status") != "active":
        return None
    if not verify_password(password or "", doc.get("password_hash")):
        return None
    return _attach_perms(doc)


def has_perm(admin: Optional[dict], perm: Optional[str]) -> bool:
    if perm is None:
        return True
    return bool(admin) and perm in admin.get("perms", set())


# ── 登录日志 + 异常(陌生 IP)识别 ──

def record_login(username: str, ip: str, ua: str) -> bool:
    """写一条登录日志,返回是否为该账号的陌生 IP(首次见 → 视作异常,前端标红)。"""
    seen_before = admin_login_log_collection.count_documents(
        {"username": username, "ip": ip}) > 0
    admin_login_log_collection.insert_one({
        "username": username, "ip": ip or "-", "ua": (ua or "")[:300],
        "is_new_ip": not seen_before, "created_at": datetime.now(),
    })
    admin_users_collection.update_one(
        {"username": username}, {"$set": {"last_login_at": datetime.now()}})
    return not seen_before


# ── 管理员账号增删改(超级管理员用) ──

USERNAME_RE = None  # 见 create_admin 内联校验


def create_admin(username: str, name: str, password: str, role: str, by: str) -> dict:
    import re
    username = (username or "").strip()
    name = (name or "").strip()
    if not re.fullmatch(r"[A-Za-z0-9_-]{3,20}", username):
        return {"ok": False, "msg": "用户名需 3~20 位字母/数字/_/-"}
    if len(password or "") < 6:
        return {"ok": False, "msg": "密码至少 6 位"}
    if role not in ROLES:
        return {"ok": False, "msg": "角色非法"}
    if admin_users_collection.find_one({"username": username}):
        return {"ok": False, "msg": f"用户名「{username}」已存在"}
    admin_users_collection.insert_one({
        "username": username, "name": name or username,
        "password_hash": hash_password(password), "role": role,
        "status": "active", "created_at": datetime.now(),
        "created_by": by, "last_login_at": None,
    })
    return {"ok": True, "msg": f"已创建管理员 {username}"}


def _count_active_superadmins(exclude_id=None) -> int:
    q = {"role": "superadmin", "status": "active"}
    if exclude_id is not None:
        q["_id"] = {"$ne": exclude_id}
    return admin_users_collection.count_documents(q)


def set_role(admin_id: str, role: str) -> dict:
    if role not in ROLES:
        return {"ok": False, "msg": "角色非法"}
    oid = ObjectId(admin_id)
    cur = admin_users_collection.find_one({"_id": oid})
    if not cur:
        return {"ok": False, "msg": "管理员不存在"}
    # 不能把最后一个超管降级
    if cur.get("role") == "superadmin" and role != "superadmin" \
            and _count_active_superadmins(exclude_id=oid) == 0:
        return {"ok": False, "msg": "至少保留一个超级管理员"}
    admin_users_collection.update_one({"_id": oid}, {"$set": {"role": role}})
    return {"ok": True, "msg": "角色已更新"}


def set_status(admin_id: str, status: str) -> dict:
    if status not in ("active", "disabled"):
        return {"ok": False, "msg": "状态非法"}
    oid = ObjectId(admin_id)
    cur = admin_users_collection.find_one({"_id": oid})
    if not cur:
        return {"ok": False, "msg": "管理员不存在"}
    if status == "disabled" and cur.get("role") == "superadmin" \
            and _count_active_superadmins(exclude_id=oid) == 0:
        return {"ok": False, "msg": "不能停用最后一个超级管理员"}
    admin_users_collection.update_one({"_id": oid}, {"$set": {"status": status}})
    return {"ok": True, "msg": "已停用" if status == "disabled" else "已启用"}


def reset_password(admin_id: str, new_password: str) -> dict:
    if len(new_password or "") < 6:
        return {"ok": False, "msg": "密码至少 6 位"}
    oid = ObjectId(admin_id)
    if not admin_users_collection.find_one({"_id": oid}):
        return {"ok": False, "msg": "管理员不存在"}
    admin_users_collection.update_one(
        {"_id": oid}, {"$set": {"password_hash": hash_password(new_password)}})
    return {"ok": True, "msg": "密码已重置"}
