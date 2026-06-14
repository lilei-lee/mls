"""管理后台审计日志:记录管理员关键操作(who / what / when / 原始数据)。

模块六设计稿要求所有强权操作(暂停/踢出/合并/状态变更等)记入 audit_log,
事后可追溯。种子期单管理员,actor 固定 "admin";后期多管理员再带 username。
"""
from datetime import datetime

from database import db


def write_audit(action: str, target_type: str, target_id, detail: dict | None = None,
                actor: str | None = None) -> None:
    if actor is None:
        try:
            from admin_auth import current_actor
            actor = current_actor.get() or "admin"
        except Exception:
            actor = "admin"
    db["audit_log"].insert_one({
        "action": action,
        "actor": actor,
        "target_type": target_type,
        "target_id": str(target_id),
        "detail": detail or {},
        "created_at": datetime.now(),
    })


# 动作中文label(审计列表展示用)
ACTION_LABEL = {
    "coop_review": "联卖审核",
    "membership_grant": "会员开通/续期",
    "listing_offline": "房源下架",
    "listing_restore": "房源恢复上架",
    "agent_ban": "踢出经纪人",
    "agent_restore": "恢复经纪人",
    "agent_suspend": "暂停经纪人",
    "agent_unsuspend": "解除暂停",
    "community_edit": "编辑小区",
    "community_merge": "合并小区",
    "community_import": "批量导入小区",
    "export": "数据导出",
    "config_update": "修改系统配置",
    "dispute_accept": "受理争议",
    "dispute_resolve": "争议裁决",
    "dispute_reject": "驳回争议",
    "deposit_proof_review": "定金凭证审核",
    "ownership_create": "发起归属变更",
    "ownership_approve": "归属变更通过",
    "ownership_reject": "归属变更驳回",
    "proxy_confirm": "代确认成交",
    "admin_create": "新建管理员",
    "admin_role_change": "调整管理员角色",
    "admin_disable": "停用管理员",
    "admin_enable": "启用管理员",
    "admin_reset_pwd": "重置管理员密码",
}
