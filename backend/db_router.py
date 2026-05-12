"""
V3 DB 路由层:根据 city 路由到对应 MongoDB database

单城运行期 DEFAULT_MLS_CITY=zhangjiakou,所有请求默认走 mls_zhangjiakou。
1.2 改造后从 JWT 读 city,支持多城切换。
"""
import os

DEFAULT_MLS_CITY = os.getenv("DEFAULT_MLS_CITY", "zhangjiakou")


def get_db(city: str | None = None):
    """根据 city 路由到对应 MongoDB database。"""
    from database import client  # 延迟 import 避免循环
    city = city or DEFAULT_MLS_CITY
    return client[f"mls_{city}"]


def get_current_city(request) -> str:
    """FastAPI dependency:从请求头 X-MLS-City 读 city。

    缺失时返回默认。1.2 改造后从 JWT 读。
    """
    city = request.headers.get("X-MLS-City")
    return city or DEFAULT_MLS_CITY
