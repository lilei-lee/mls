"""后台:经纪人会员开通 / 续期 / 查看(按手机号设到期日)。

这是"后台控制"会员的运维工具(Web 管理后台做好前先用它)。

用法:
    cd C:\\projects\\mls\\backend
    venv\\Scripts\\activate
    python scripts\\grant_membership.py --list                  # 查看所有人会员状态
    python scripts\\grant_membership.py 13912345678 365          # 从今天起 +365 天
    python scripts\\grant_membership.py 13912345678 --until 2027-01-01

注:开关 MEMBERSHIP_ENFORCED=false(免费期)时,到期日不影响使用;
   想真正开始收费,设环境变量 MEMBERSHIP_ENFORCED=true 后,只有到期日在
   未来的经纪人才有完整权限,其余只读。
"""
import sys
from datetime import datetime, timedelta

from database import db
from membership import set_membership_by_phone


def list_members():
    print("=== 经纪人会员状态 ===")
    now = datetime.now()
    for a in db["agents"].find({}, {"phone": 1, "name": 1, "membership_expires_at": 1}):
        exp = a.get("membership_expires_at")
        if isinstance(exp, datetime):
            tag = "有效" if exp > now else "已过期"
            exp_s = exp.strftime("%Y-%m-%d")
        else:
            tag, exp_s = "未开通", "-"
        print(f"  {a.get('name', '?')} {a.get('phone', '?')}: {exp_s} ({tag})")


def main(args):
    if not args or args[0] == "--list":
        list_members()
        return

    phone = args[0]
    if len(args) >= 3 and args[1] == "--until":
        try:
            expires = datetime.strptime(args[2], "%Y-%m-%d")
        except ValueError:
            print("日期格式应为 YYYY-MM-DD")
            return
    elif len(args) >= 2:
        try:
            expires = datetime.now() + timedelta(days=int(args[1]))
        except ValueError:
            print("天数应为整数")
            return
    else:
        print("用法: grant_membership.py <phone> <days> | <phone> --until YYYY-MM-DD | --list")
        return

    res = set_membership_by_phone(phone, expires)
    if not res["matched"]:
        print(f"未找到手机号 {phone} 的经纪人")
        return
    print(f"已为 {res['agent_name']}({phone}) 设会员到期日: {res['expires_at']}")


if __name__ == "__main__":
    main(sys.argv[1:])
