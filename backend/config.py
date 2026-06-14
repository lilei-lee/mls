"""
MLS 统一配置中心
所有环境变量从这里集中读取，提供合理默认值。

用法:
    from config import MONGO_URI, SECRET_KEY, MINIO_ENDPOINT

生产部署时通过环境变量覆盖以下关键配置:
    MONGO_URI, SECRET_KEY, MINIO_ACCESS_KEY, MINIO_SECRET_KEY
"""
import os


# ==================== MongoDB ====================

MONGO_URI: str = os.getenv("MONGO_URI", "mongodb://localhost:27017")


# ==================== JWT ====================

# ⚠️ 生产环境必须通过环境变量 SECRET_KEY 覆盖此默认值，
# 否则重启后所有已签发 token 将失效（因为密钥变了）。
# 当前默认值保留旧硬编码值，保证存量 token 可继续使用。
_SECRET_KEY_DEFAULT = "3Qy1db3aKPG4cVCk3132qtE-m9w0OSb7W-BUbnM3RZs"
SECRET_KEY: str = os.getenv("SECRET_KEY", _SECRET_KEY_DEFAULT)

ALGORITHM: str = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS: int = 2
REFRESH_TOKEN_EXPIRE_DAYS: int = 30


# ==================== MinIO 对象存储 ====================

MINIO_ENDPOINT: str = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY: str = os.getenv("MINIO_ACCESS_KEY", "")
MINIO_SECRET_KEY: str = os.getenv("MINIO_SECRET_KEY", "")
MINIO_BUCKET: str = os.getenv("MINIO_BUCKET", "mls-photos")
MINIO_SECURE: bool = os.getenv("MINIO_SECURE", "false").lower() == "true"


# ==================== 开发模式 ====================

DEV_SMS_CODE: str = os.getenv("DEV_SMS_CODE", "123456")


# ==================== 会员费机制 ====================

# 默认 false = 免费试用期(人人完整可用,不拦任何写操作)。
# 想开始收费时设环境变量 MEMBERSHIP_ENFORCED=true:
#   到期日在未来的经纪人 = 有效会员;否则 = 只读(写操作返 402)。
MEMBERSHIP_ENFORCED: bool = os.getenv("MEMBERSHIP_ENFORCED", "false").lower() == "true"

# 注册时是否自动送固定天数试用(0 = 不送,完全靠开关 + 后台手动开通)
MEMBERSHIP_TRIAL_DAYS: int = int(os.getenv("MEMBERSHIP_TRIAL_DAYS", "0"))
