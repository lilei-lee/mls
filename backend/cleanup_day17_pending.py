"""Day 17 测试前清理:删除 5 条重复的 pending_confirm 带看记录。"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
from database import db
from bson import ObjectId

# 1. 备份
backup_name = 'showings_backup_day17_cleanup'
if db[backup_name].count_documents({}) > 0:
    print(f'[backup] {backup_name} 已存在,跳过')
else:
    list(db['showings'].aggregate([{'$out': backup_name}]))
    cnt = db[backup_name].count_documents({})
    print(f'[backup] 已备份 {cnt} 条到 {backup_name}')

# 2. 删除
ids = [
    '69f0d98a6f6c7382ec8c76d4',
    '69f0d98c6f6c7382ec8c76d5',
    '69f0d98e6f6c7382ec8c76d6',
    '69f0d98f6f6c7382ec8c76d7',
    '69f0d9976f6c7382ec8c76d8',
]
res = db['showings'].delete_many({'_id': {'$in': [ObjectId(x) for x in ids]}})
print(f'[delete] 删了 {res.deleted_count} 条 (期望 5)')

# 3. 验证
remaining = db['showings'].count_documents({
    'listing_snapshot.community': '保利中央公园',
    'listing_snapshot.building': '4',
    'status': 'pending_confirm',
})
print(f'[verify] 剩余 pending_confirm: {remaining} (期望 0)')
