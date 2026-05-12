# 辞典后端测试

## pytest 单测(自动)
- test_claim_service.py
- test_v2_2_schema.py
- 其他 test_*.py

运行:
venv\Scripts\python.exe -m pytest tests/ -v

## 集成测试(手动)
- integration_test_api.py:启动 uvicorn 后手动 python 跑
