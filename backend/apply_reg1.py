import sys
sys.stdout.reconfigure(encoding='utf-8')
from database import db

print('=' * 70)
print('APPLY: 回填 showings customer_* 字段')
print('=' * 70)

all_showings = list(db['showings'].find({}).sort('created_at', 1))
updated_count = 0

for s in all_showings:
    oid = s['_id']
    cid = s.get('customer_id')
    sn = s.get('customer_surname')
    gd = s.get('customer_gender')
    req_id = s.get('showing_request_id')

    if cid is None and sn is None and gd is None:
        if req_id is None:
            print(f'跳过 {str(oid)[-6:]}: 无 showing_request_id')
            continue

        req = db['showing_requests'].find_one({'_id': req_id})
        if req is None:
            print(f'跳过 {str(oid)[-6:]}: 对应 request 不存在')
            continue

        update = {}

        if cid is None:
            update['customer_id'] = req.get('customer_id')
        if sn is None:
            update['customer_surname'] = req.get('customer_surname')
        if gd is None:
            update['customer_gender'] = req.get('customer_gender')

        if not update:
            print(f'跳过 {str(oid)[-6:]}: 无需更新')
            continue

        fields = list(update.keys())
        print(f'将更新 {str(oid)[-6:]} 的字段: {fields}')

        result = db['showings'].update_one(
            {'_id': oid},
            {'$set': update}
        )
        updated_count += result.modified_count
    else:
        print(f'跳过 {str(oid)[-6:]}: 已有数据,保留')

print()
print(f'apply 完成,总更新 {updated_count} 条')