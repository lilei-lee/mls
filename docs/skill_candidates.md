# Skill 候选清单

> 生成时间：2026-04-29（Day 17）
> 来源：扫描 CLAUDE.md 中重复出现的工作流模式

---

| # | Skill 名称 | 触发场景 | 自动化收益 | 实现复杂度 |
|---|-----------|----------|-----------|-----------|
| 1 | `mls-pydantic-field` | 给后端模型加新字段时 | 自动检查并补全三处（doc 模型 + CreateRequest + UpdateRequest），防止坑 1 沉默丢弃。每次手动加字段都要翻三个文件对照，skill 可以一次扫描+提醒遗漏 | 低：只需定位特定 .py 文件中的 Pydantic class 定义 |
| 2 | `mls-viewer-aware` | 修改 transactions.py / settlements.py 的 `_format` 函数时 | 自动检查 `_format` 是否接受 `viewer_id` 参数、是否正确脱敏 `ba_deal_*` 系列字段。这是反作弊基石，破坏一次等于核心商业价值受损 | 中：需要理解函数签名和返回字典结构，做语义级检查而非简单 grep |
| 3 | `mls-pitfall-check` | 任何代码修改前（改文件后 commit 前） | 自动跑一遍：flutter analyze / 后端 import 检查 / 路由命名表对照 / distinct status 检查 / 双视角验证提醒。相当于把"改文件后的默认动作"和"不能做的事"自动化 | 中：需要集成 flutter analyze + 部分规则可脚本化 |
| 4 | `mls-route-check` | 新增/修改前端页面跳转代码时 | 根据第九节"路由命名速查表"自动校验跳转路径是否正确（单复数、中划线、/confirm 后缀等）。Day 15 末暴露的 404 就是因为路由名写错 | 低：规则表是静态的，可以直接编码为校验规则 |
| 5 | `mls-handoff-gen` | 每个 Day 结束或磊说"生成交接档"时 | 自动读取 git log 当天变更、CLAUDE.md 最新坑库、当前阶段描述，生成 handoff/V8_X.md 交接文档。避免人工漏写或遗忘当天决策 | 中：需要聚合 git diff + CLAUDE.md 结构化信息生成 Markdown |

---

## 备注

- 候选 1 和 4 复杂度最低，建议优先实现
- 候选 3 是最通用的"工程纪律 guard"，覆盖范围最广，但实现面也最广
- 候选 2 是最关键的（反作弊保护），但语义检查难度最高
- 候选 5 的价值在于确保知识不丢失，但需要定义好 handoff 模板
