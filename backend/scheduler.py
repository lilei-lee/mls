"""
MLS 定时任务调度器
作者:磊(Day 9)

用 APScheduler 跑后台定时任务:
- expire_stale_showing_requests: 每天凌晨 3:00 把 7 天未处理的 pending 申请标为 expired
"""

from datetime import datetime, timedelta
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from database import db


# ============= 任务函数 =============

def expire_stale_showing_requests():
    """把超过 7 天未处理的 pending 带客申请批量改为 expired。
    每天凌晨 3:00 跑一次。
    """
    from system_config import get_config
    cutoff = datetime.now() - timedelta(days=get_config("showing_request_expire_days", 7))
    result = db["showing_requests"].update_many(
        {
            "status": "pending",
            "created_at": {"$lt": cutoff},
        },
        {
            "$set": {
                "status": "expired",
                "reject_reason": "expired",
                "reject_extra": "申请 7 天未处理,系统自动过期",
                "reviewed_at": datetime.now(),
                "updated_at": datetime.now(),
            }
        }
    )
    print(f"⏰ 定时任务 expire_stale_showing_requests 完成:"
          f"处理了 {result.modified_count} 条过期申请 "
          f"({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")


# ============= 调度器装配 =============

_scheduler: AsyncIOScheduler | None = None


def start_scheduler():
    """由 main.py 的 lifespan 在启动时调用"""
    global _scheduler
    if _scheduler is not None:
        return
    _scheduler = AsyncIOScheduler()

    # 每天凌晨 3:00 执行
    _scheduler.add_job(
        expire_stale_showing_requests,
        CronTrigger(hour=3, minute=0),
        id="expire_stale_showing_requests",
        replace_existing=True,
    )

    _scheduler.start()
    print("[OK] 定时任务调度器已启动(每天 03:00 扫过期申请)")


def stop_scheduler():
    """由 main.py 的 lifespan 在关闭时调用"""
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        print("定时任务调度器已关闭")