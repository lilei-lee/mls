"""pytest 全局配置。

测试隔离策略(磊 2026-06-14 决策:mongomock 全隔离):

1. **mongomock 内存库**:把 `pymongo.MongoClient` 换成内存版,所有测试不碰真
   MongoDB,与生产数据完全隔离(此前 test_filter_orientation 因真库里有 11 条
   "朝南" 遗留数据而 assert 11==1 —— 内存库每次全新,根除此类污染)。无需起
   mongod 也能跑,CI 友好。

2. **每个测试前清空**:mongomock 全进程共享一个内存库;每测试前清空保证用例
   间隔离(所有 DB 类测试的 fixture 均 function-scoped,各自建数据)。

3. **smoke 自动跳过**:test_smoke 用 requests 打 localhost:8000,需要运行中的
   后端。检测不到服务时自动 skip,不以 ConnectionError 计失败。

必须在任何 test 模块 import database 之前打 mongomock 补丁 —— conftest.py 由
pytest 最先加载,满足前置条件。
"""
import socket

import mongomock
import pymongo
import pytest

# ── 1. mongomock 内存库(必须在导入 storage/database 之前打补丁) ──
pymongo.MongoClient = mongomock.MongoClient

# 副作用桩:对象存储 / 定时任务在单测里不需要真启动
try:
    import storage
    storage.ensure_bucket = lambda: None
except Exception:
    pass
try:
    import scheduler
    scheduler.start_scheduler = lambda: None
    scheduler.stop_scheduler = lambda: None
except Exception:
    pass


# ── 2. 每个测试前清空内存库(用例间隔离) ──
@pytest.fixture(autouse=True)
def _isolate_db():
    from database import db
    for name in db.list_collection_names():
        db[name].delete_many({})
    yield


# ── 3. 无后端服务时跳过 smoke ──
def _server_up(host="localhost", port=8000, timeout=0.3):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def pytest_collection_modifyitems(config, items):
    if _server_up():
        return  # 后端在跑,正常执行 smoke
    skip_smoke = pytest.mark.skip(
        reason="需要运行中的后端(localhost:8000),已自动跳过 smoke"
    )
    for item in items:
        loc = str(getattr(item, "path", "") or getattr(item, "fspath", ""))
        if "test_smoke" in loc:
            item.add_marker(skip_smoke)
