# MLS 项目优化报告

> 基于跨 session 观察（Day 10 → V3 段 1.1 → 视觉规范批次 1/2），按投入产出比排序。

---

## 一、立刻做（< 1 小时，极高杠杆）

### 1. pre-commit hook：flutter analyze

```
文件：.git/hooks/pre-commit
内容：
  #!/bin/sh
  cd app/mls_app && flutter analyze
```

- **价值**：铁律 5 要求 `flutter analyze 0 error` 才停手，现在靠人记。hook 机械化后每次 commit 自动拦
- **成本**：15 分钟
- **风险**：无。只拦 error，不拦 warning/info

### 2. `.env` 统一管理

- **现状**：配置散落三处 —— `backend/database.py`（`MONGO_URI`）、`backend/db_router.py`（`DEFAULT_MLS_CITY`）、`property-dictionary/backend/.env`（`DICT_*` 系列）
- **方案**：加 `backend/.env.example`，用 `python-dotenv` 统一加载。新机器拉下来只改一个文件，不用翻源码找 env var
- **成本**：20 分钟

### 3. 文档版本墙

- **问题**：`docs/` 里 V9/V10 设计文档覆盖面远大于代码实际实现。新 Claude Code session 读到 `docs/` 可能把设计文档当事实，不知道 CLAUDE.md 第十八节有已实现度速查表
- **方案**：`docs/README.md` 加索引表，每份设计文档标注对应代码实现度百分比，桥接 CLAUDE.md 速查表
- **成本**：20 分钟

---

## 二、本周做（1-3 小时，显著体验改善）

### 4. pytest 分组运行

- **问题**：`pytest tests/` 全量跑，HTTP 测试（test_smoke / test_community_detail / test_listing_crud 等）server 不在时 69 failed。真正的单测失败淹没在其中
- **方案**：
  ```ini
  # backend/pytest.init
  [pytest]
  markers =
      unit: 独立单测，不依赖 HTTP/MongoDB
      integration: 依赖 server 或真实 MongoDB
  ```
  给 test_db_router / test_dictionary_client / test_audit_log 等标注 `@pytest.mark.unit`
  `pytest -m unit` 只跑关键单测，30 秒出结果
- **成本**：30 分钟

### 5. 后端健康检查脚本

- **文件**：`health_check.cmd`
  ```cmd
  @echo off
  echo MLS Backend (8000):
  curl -s -o NUL -w "%%{http_code}" http://localhost:8000/
  echo.
  echo Dictionary (8001):
  curl -s -o NUL -w "%%{http_code}" http://localhost:8001/health
  echo.
  pause
  ```
- **价值**：双击知两服务状态，不用开浏览器。可合并进 `start_dev.cmd`
- **成本**：10 分钟

### 6. `test_smoke.py` 拆分

- **问题**：160 行 50 测试塞一个文件。fixture 链 6 层深（token → listing → showing_request → showing → transaction），失败根因要翻十几屏 traceback
- **方案**：拆成 `test_auth.py` / `test_listings.py` / `test_transactions.py` / `test_collaborations.py` / `test_customers.py`，各管各的模块
- **成本**：1 小时

---

## 三、本月做（3-8 小时，架构改善）

### 7. MongoDB 自动备份

- **文件**：`backup.cmd`
  ```cmd
  @echo off
  set BACKUP_DIR=C:\backup\mls_%date:~0,10%
  mongodump --db mls_zhangjiakou --out %BACKUP_DIR%
  echo [OK] Backup saved to %BACKUP_DIR%
  ```
- **配 Windows 任务计划**：每天凌晨 3:00 执行
- **价值**：当前手动 mongodump 依赖记忆，忘一次多 24h 数据风险窗口。V3 已迁移到 `mls_zhangjiakou`，备份就绪后多城扩展才有兜底
- **成本**：30 分钟写脚本 + 10 分钟配任务计划

### 8. Pydantic 校验补强

- **现状**（已登 CLAUDE.md V8.4 技术债）：`price_wan` 允许负数、姓名允许 50 字、备注允许 1000 字。后端关键字段无校验
- **方案**：用户可编辑字段加 Pydantic validator —— 数值范围、长度限制、枚举白名单。这是后端数据卫生第一道闸
- **成本**：2-3 小时

### 9. flutter analyze → GitHub Actions（CI 过渡）

- **模板**：
  ```yaml
  # .github/workflows/analyze.yml
  name: Flutter Analyze
  on: [push, pull_request]
  jobs:
    analyze:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: subosito/flutter-action@v2
        - run: cd app/mls_app && flutter pub get && flutter analyze
  ```
- **价值**：push 时自动跑，多人协作后必需品。当前单人开发不急，但模板先放在那
- **成本**：30 分钟

---

## 四、不动（有意识搁置）

| 项目 | 原因 |
|---|---|
| **实时推送**（WebSocket/SSE） | V8.4 已登债。影响面大，批量审批等核心功能先稳再补。50 户上线后做 |
| **Dark mode 完整主题** | 批次 1 已预留色值，但完整深色模式是 V2 范围。当前只在局部深色面板用 |
| **大规模重构**（CLAUDE.md 拆分、目录重构、ORM 迁移） | 当前结构不完美但工作体感已建立。重构成交成本高，没到复杂度临界点 |
| **Flutter widget test 补齐** | `widget_test.dart` 还是默认 counter 测试。widget test 维护成本高，单人开发期 UI 回归靠真机点 |
| **多城完整上线** | V3 段 1.1 已做基础路由层，但真正多城需 JWT 读 city + 数据隔离策略 + 运维方案，50 户阶段不急 |
| **COS 对象存储迁移** | CLAUDE.md 已标注必做，但需先申请腾讯/阿里/七牛账号。照片 base64 存 MongoDB 在 50 户内可接受 |

---

## 优先级矩阵

```
                    时间      杠杆      做?
──────────────────────────────────────────
1. pre-commit hook   15min    极高      ⭐
2. .env 统一管理      20min    极高      ⭐
3. 文档版本墙         20min    高        ⭐
4. pytest 分组        30min    高
5. 健康检查           10min    中
6. test_smoke 拆分    1h       中
7. MongoDB 备份       40min    中
8. Pydantic 校验      2-3h     高
9. GitHub Actions    30min    低        先搁
```

---

## 本周最小可行包

**1 + 2 + 3 = 55 分钟**，覆盖三个核心风险面：

- **启动安全**（1）: 每次 commit 自动挡 break
- **环境配置**（2）: 新机器/新人拉下来只改一个文件
- **AI 交接**（3）: 新 session 不会把设计当代码

做完这三项再推进 4-8。

---

**报告版本**：V1.0 · 2026-05-13
**生成背景**：V3 段 1.1 收口 + 视觉规范批次 2 验收通过
