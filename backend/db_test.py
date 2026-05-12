"""
MongoDB 连接测试 + 插入第一条经纪人数据
运行一次就好,目的是验证:
  1. Python 能连上 MongoDB
  2. 能写入数据
  3. 能读出数据
"""
from datetime import datetime
from pymongo import MongoClient

# ==================== 连接 MongoDB ====================
client = MongoClient("mongodb://localhost:27017")
db = client["mls"]                     # 数据库
agents_collection = db["agents"]       # 经纪人集合

print(f"[OK] 已连接到 MongoDB: {client.address}")
print(f"[OK] 数据库: mls,集合: agents")
print(f"  当前 agents 集合里有 {agents_collection.count_documents({})} 条数据")

# ==================== 插入第一个经纪人 ====================
first_agent = {
    "phone": "15830312288",
    "name": "李磊",
    "id_card": "130702198408210811",
    "avatar_url": "",
    "store_id": "S001",
    "store_name": "张家口新概念房地产经纪有限公司",
    "role": "boss",
    "status": "active",
    "coop_verified": False,
    "created_at": datetime.now(),
    "updated_at": datetime.now(),
    "last_login_at": None,
    "devices": [],
    "wechat_unionid": None,
}

# 检查是否已存在,避免重复插入
existing = agents_collection.find_one({"phone": first_agent["phone"]})
if existing:
    print(f"\n⚠️ 手机号 {first_agent['phone']} 已存在,跳过插入")
    print(f"   现有数据 _id: {existing['_id']}")
else:
    result = agents_collection.insert_one(first_agent)
    print(f"\n[OK] 成功插入经纪人!")
    print(f"   _id: {result.inserted_id}")
    print(f"   姓名: {first_agent['name']}")
    print(f"   手机: {first_agent['phone']}")
    print(f"   门店: {first_agent['store_name']}")

# ==================== 读出来验证 ====================
print(f"\n当前 agents 集合里的所有经纪人:")
for agent in agents_collection.find():
    print(f"  • {agent['name']} ({agent['phone']}) - {agent['store_name']}")

print(f"\n总计: {agents_collection.count_documents({})} 条")