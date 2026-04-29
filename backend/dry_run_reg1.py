import sys
sys.stdout.reconfigure(encoding='utf-8')
from database import db

print('=' * 70)
print('DRY-RUN: 全部 showings 当前 customer_* 状态')
print('=' * 70)

all_showings = list(db['showings'].find({}).sort('created_at', 1))
none_docs = []
has_docs = []

for s in all_showings:
    oid = str(s['_id'])
    cid = s.get('customer_id')
    sn = s.get('customer_surname')
    gd = s.get('customer_gender')
    req_id = s.get('showing_request_id')

    is_none = (cid is None and sn is None and gd is None)

    if is_none:
        none_docs.append(s)
        status = 'NEED_BACKFILL'
    else:
        has_docs.append(s)
        status = 'OK'

    req_tail = str(req_id)[-6:] if req_id else 'N/A'
    print(f'[{status}] showing {oid[-6:]}: customer_id={cid} surname={sn!r} gender={gd!r} req={req_tail}')

print()
print(f'总计: {len(all_showings)} 条 | 已有数据: {len(has_docs)} 条 | 待回填: {len(none_docs)} 条')

print()
print('=' * 70)
print(f'待回填 {len(none_docs)} 条: 对应 showing_request 的 customer 字段')
print('=' * 70)

for s in none_docs:
    oid = str(s['_id'])
    req_id = s.get('showing_request_id')
    if req_id is None:
        print(f'showing {oid[-6:]}: no showing_request_id')
        continue

    req = db['showing_requests'].find_one({'_id': req_id})
    if req is None:
        print(f'showing {oid[-6:]} <- request {str(req_id)[-6:]}: REQUEST NOT FOUND')
        continue

    print(f'showing {oid[-6:]} <- request {str(req_id)[-6:]}:')
    print(f'  request customer_id={req.get("customer_id")}')
    print(f'  request customer_surname={req.get("customer_surname")!r}')
    print(f'  request customer_gender={req.get("customer_gender")!r}')
    print(f'  request status={req.get("status")}')

print()
print('DRY-RUN 结束. Step 3: 请用户审核。')
