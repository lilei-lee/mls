"""pytest 全局配置(2026-06-14 加)。

**test_smoke 自动跳过**:`test_smoke` 用 requests 打 `localhost:8000`,需要运行中
的后端。检测不到服务时自动 skip,不再以 ConnectionError 计为失败(磊那 46 个
smoke 误失败的来源)。服务在跑时正常执行。

注:DB 类单测直接连 `database.py` 配置的 Mongo(磊本机有 Mongo)。本项目暂不
在 conftest 里强制 mongomock——那会让本机真 Mongo 被内存库覆盖,且全量跑存在
跨文件状态污染(单文件全绿、合并跑红),反而引入真 Mongo 上没有的失败。
hermetic / 无 Mongo CI 是独立的测试隔离工程,登债(见下方 triage 报告)。
"""
import socket

import pytest


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
