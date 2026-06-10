"""Shim — 将 listings 模块透明代理到 services.listings。

所有 `from listings import _xxx` 的引用无需修改。
"""
import sys as _sys
from services import listings as _actual
_sys.modules[__name__] = _actual
