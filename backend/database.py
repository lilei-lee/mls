"""
数据库连接模块
统一管理 MongoDB 连接,供其他模块导入使用
"""
from pymongo import MongoClient

# MongoDB 连接配置
MONGODB_URL = "mongodb://localhost:27017"
DATABASE_NAME = "mls"

# 全局 MongoDB 客户端(一次连接,全局复用)
client = MongoClient(MONGODB_URL)
db = client[DATABASE_NAME]

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