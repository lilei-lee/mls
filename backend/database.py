"""
数据库连接模块
统一管理 MongoDB 连接,供其他模块导入使用

V3: db 通过 db_router.get_db() 路由,支持多 city database。
单城运行期默认走 mls_zhangjiakou。
"""
import os
from pymongo import MongoClient
from db_router import get_db

# MongoDB 连接配置
MONGODB_URL = os.getenv("MONGO_URI", "mongodb://localhost:27017")

# 全局 MongoDB 客户端(一次连接,全局复用)
client = MongoClient(MONGODB_URL)

# V3: db 由 city 路由决定,单城默认 mls_zhangjiakou
db = get_db()

# 暴露各个集合,方便其他模块导入
agents_collection = db["agents"]      # 经纪人集合
houses_collection = db["houses"]      # 房源集合(以后用)
brokers_collection = db["brokers"]    # 带客申请集合(以后用)


def ping():
    """测试数据库连接是否正常"""
    try:
        # admin.command('ping') 是 MongoDB 标准的健康检查
        client.admin.command("ping")
        return True
    except Exception as e:
        print(f"❌ MongoDB 连接失败: {e}")
        return False