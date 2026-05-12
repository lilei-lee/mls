# MLS 视觉规范 V1 接入进度

## 安全锚点
| 批次 | commit | 内容 | 真机验证 |
|---|---|---|---|
| 批次 1 token 层 | bc9907b | 6 个 mls_*.dart token + main.dart 切换 | ✅ 5 Tab 全过 |
| 批次 2 基础组件 | (待) | MlsCard / MlsAvatar / MlsStatusBadge / MlsPrimaryButton / MlsSectionHeader / MlsSegmentedControl | - |
| 批次 3 专用组件 | (待) | MlsHeroToday / MlsMetricCell / MlsProgressRing / MlsProgressStepper / MlsEncryptedPanel / MlsMoneyInput | - |
| 批次 4 页面落地 | (待) | home_screen / dashboard / transaction_confirm 三页重做 | - |

## 已知遗留
- AppTheme 旧 token 系统仍在使用，主要影响 home_screen.dart 的 SliverAppBar Header（蓝渐变 + 白字）。计划在批次 4 重做 home_screen 时移除 AppTheme 引用，迁移到 MlsColors

## 回滚指南
- 完整回退到批次 1 起点：git reset --hard bc9907b
- 仅回退 theme 引用：main.dart 取消注释原 theme，注释掉 MlsTheme.light

## 跨 session 交接
任何新的 Claude Code session 接手时，先读本文件再读 _incoming/（如有）。

铁律：
- 本文件由你（Claude Code）维护，每完成一个批次或重大变更时更新
- 表格里的 commit 列由我（磊）确认 commit 后告诉你写入，你不要自己猜
- 不要 git add / git commit 本文件，由我手动操作
