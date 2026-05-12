# Bridge 工具链 PoC 前置验证 — Claude Code CLI 非交互式调用能力

**日期**: 2026-05-07 | **CLI 版本**: `@anthropic-ai/claude-code@2.1.132`

---

## Step 1: `--help` 关键参数

### 非交互模式

| 参数 | 说明 |
|---|---|
| `-p, --print` | **核心参数**。打印结果后退出（适用于 pipes）。非交互模式下跳过工作区信任弹窗 |
| `--no-session-persistence` | 不保存 session 到磁盘（仅配合 `--print`） |
| `--permission-mode <mode>` | 权限模式：`acceptEdits` / `auto` / `bypassPermissions` / `default` / `dontAsk` / `plan` |

### 结构化输出

| 参数 | 说明 |
|---|---|
| `--output-format <format>` | `text` (默认) / `json` (单结果) / `stream-json` (实时流) |
| `--input-format <format>` | `text` (默认) / `stream-json` (实时流输入) |
| `--json-schema <schema>` | JSON Schema 约束输出结构 |
| `--include-partial-messages` | 流式输出时包含部分消息块 |

### 会话控制

| 参数 | 说明 |
|---|---|
| `--session-id <uuid>` | 指定 session ID |
| `-c, --continue` | 继续最近对话 |
| `-r, --resume [id]` | 按 ID 恢复会话 |
| `--fork-session` | 恢复时创建新 session ID |

### 成本控制

| 参数 | 说明 |
|---|---|
| `--max-budget-usd <amount>` | API 调用最大花费（仅 `--print`） |
| `--effort <level>` | 模型 effort 级别 |

### 其他脚本相关

| 参数 | 说明 |
|---|---|
| `--system-prompt <prompt>` | 自定义 system prompt |
| `--append-system-prompt <prompt>` | 追加 system prompt |
| `--agents <json>` | 加载自定义 agent |
| `--bare` | 最小模式：跳过所有 hooks/LSP/CLAUDE.md 自动发现 |
| `--allowed-tools <tools>` | 工具白名单 |
| `--settings <file>` | 加载 settings JSON |

### 调用语法

```
claude -p "your prompt" [options]
echo "prompt" | claude -p - [options]
claude -p "$(cat prompt.txt)" [options]
```

`prompt` 为位置参数；`-` 表示从 stdin 读取。

---

## Step 2: 实测结果

### Test 1: 基础文本输出 ✅

```bash
$ claude -p "echo hello" --no-session-persistence --output-format text
hello
```

### Test 2: JSON 结构化输出 ✅

```bash
$ claude -p "What is 2+3?" --no-session-persistence --output-format json
```

返回完整 JSON：包含 `result`, `duration_ms`, `num_turns`, `total_cost_usd`, `usage`, `session_id` 等字段。

### Test 3: 工具调用（文件读取）✅

```bash
$ claude -p "Read C:/projects/mls/README.md and tell me the first line." --permission-mode auto
```

成功调用 Read 工具读取文件并返回结果。

### Test 4: stdin 管道输入 ✅

```bash
$ echo 'tell me the current date' | claude -p - --no-session-persistence
Today is 2026-05-07.
```

---

## Step 3: 文档/社区发现

CLI 输出中明确标注：

> `-p, --print` — "Print response and exit (useful for pipes)"
> "The workspace trust dialog is skipped when Claude is run in non-interactive mode (via -p, or when stdout is not a TTY)"

这表明非交互式调用是**官方设计的用例**，不是实验性功能。

`--bare` 模式进一步确认了 headless 场景的意图：
> "Minimal mode: skip hooks, LSP, plugin sync, attribution, auto-memory, background prefetches, keychain reads, and CLAUDE.md auto-discovery."

---

## Step 4: Plan B 评估

**不需要 Plan B。** `--print` 模式已满足 bridge 全部需求：

- python `subprocess.run(["claude", "-p", prompt, "--output-format", "json", ...])` 即可完成非交互式调用
- JSON 输出可直接解析：`result` 字段是响应文本，`is_error` 标识异常，`total_cost_usd` 做成本追踪
- `--permission-mode auto` 或 `bypassPermissions` 跳过交互确认
- `--session-id` + `--resume` 支持多轮上下文复用

如果 Web Claude 需要流式响应，`--output-format stream-json` 提供 SSE 风格实时输出。

---

## 结论

**A) 完全可行。** ✅

Bridge PoC 的技术路径清晰：

```
Web Claude 发 JSON 工单
→ 磊的 PC 上 Python bridge 脚本
→ subprocess.run(["claude", "-p", prompt, "--output-format", "json", "--no-session-persistence", "--permission-mode", "auto"])
→ 解析 JSON result
→ 回传 Web Claude
```

核心能力全部就位：非交互执行、结构化输出、工具调用、成本追踪、会话复用、stdin 管道。
