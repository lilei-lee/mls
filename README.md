# MLS — 张家口二手房经纪人协作系统

B 端 SaaS。**不抽佣，靠会员费**。模仿美国 MLS 机制：LA 挂房 → 共享 → BA 带客 → 双方独立留痕合作 → 成交 → 奖金结算。

核心理念：**机制服务于信任的演化**。

---

## 项目状态

- **当前阶段**：V2 完成度 94%（Day 16 末）
- **下阶段**：内部系统性测试 + 🔴 高优先级技术债清理（COS 迁移 + 历史数据回填）
- **运营**：种子用户阶段（待启动）

## 技术栈

- **前端**：Flutter 3.41.7 + Dart 3.11.5
- **后端**：FastAPI + Python 3.11 + MongoDB 8.2
- **鉴权**：JWT（access 2h + refresh 30d + Token Rotation）
- **平台**：Android 优先，iOS 预留

## 起服务老三样

```cmd
ipconfig                                       :: 查 IP

cd C:\projects\mls\backend
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000

:: 新开 cmd
cd C:\projects\mls\app\mls_app
flutter run
```

## 测试账号

| 身份 | 手机号 | 角色 |
|---|---|---|
| 张三 | 13912345678 | LA（挂牌经纪人）|
| 李红 | 13200132000 | BA（带客经纪人）|

验证码开发期固定 `1234`。

## 文档导航

- **`CLAUDE.md`** — Claude Code 工作手册（**核心**，含技术栈、铁律、坑库、协作约定）
- `docs/` — 业务设计文档（V10 决策汇总 + 7 个模块设计稿）
- `handoff/V8_2.md` — 当前最新交接档（Day 16 末）
- `handoff/archived/` — 历史交接档（V7.2 / V8.1 / V8.2）

## 开发流程

本项目使用 Claude Code协助开发。新对话首次接触项目，请先完整阅读 `CLAUDE.md`。

```cmd
cd C:\projects\mls
claude
```

## 项目作者

磊（创始人 + 唯一开发者）+ Claude（AI 协作伙伴）

----------

> *9 个月，从 0 到 V2 94%，31 个坑，80+ 个产品决策，3 次大重构，1 次跨电脑迁移。*
