# MLS 视觉规范 V1 接入进度

## 安全锚点
| 批次 | commit | 内容 | 真机验证 |
|---|---|---|---|
| 批次 1 token 层 | bc9907b | 6 个 mls_*.dart token + main.dart 切换 | ✅ 5 Tab 全过 |
| 批次 2 基础组件 | a8cedd9 | MlsCard / MlsAvatar / MlsStatusBadge / MlsPrimaryButton / MlsSectionHeader / MlsSegmentedControl | ✅ 6/6 预览页全过 |
| 批次 3 专用组件 | 508974f (主体), 280208a (修补) | MlsHeroToday / MlsMetricCell / MlsProgressRing / MlsProgressStepper / MlsEncryptedPanel / MlsMoneyInput | ✅ 7/7 全过, 含 pulse 呼吸 + 扫描线动画 + 千分位 + 万元换算 |
| 批次 4 页面落地 | ✅ | home_screen 完整 V1 + transaction_detail V1 (dashboard 留待后续) | - |
|  └ 4A.2.b home_screen token 迁移 | b449fcc | 30 处 AppTheme → Mls | ✅ 真机 |
|  └ 4A.2.c 前半 轻量组件替换 | 39005b6 | AppAvatar/Card/Section → Mls 组件 (5 处) | ✅ 真机 |
|  └ 4A.2.c.3 AppSection→_wrapSection | 28702ab | 3 处 AppSection → _wrapSection + MlsSectionHeader | ✅ 真机 |
|  └ 4A.2.c.4 收尾 | b2d7cc5 | radiusM→MlsRadius.xl + 删 3 unused import | ✅ 真机 |
|  └ 4A.3 待办 badge | e47d65d | _pill → MlsStatusBadge (3 处) | ✅ 真机 |
|  └ 4C.3 反作弊 MlsEncryptedPanel | 9eaf92a | _submissionTile masked 状态 → MlsEncryptedPanel | ✅ 真机 |
|  └ 4C.1+2+4 transaction 3 组件 | 9b37608 | _statusBanner/MlsProgressStepper/_submissionTile Card | ✅ 真机 |
|  └ 5 字 bug fix | 2650557, fd81a85, 0595216 | 3 Tab + FAB + TabBar 标签色 | ✅ 真机 |
| 批次 5 全工程 AppTheme → Mls | e4bcf6e~0595216 | 全工程 ~800+ 处 AppTheme 迁移到 Mls token (9 轮批量) | ✅ analyze 0 error |
| 批次 5 收尾 | (本次 commit) | AppTheme 清零 (仅 AppTheme._() 残留), home_screen 2 info 修, 删旧组件 | - |

## 已知遗留
- AppTheme 类定义本身保留 (lib/theme/app_theme.dart), 仅剩 `AppTheme._()` 私有构造, 等最后手动删除
- AppCard 组件仍有 2 处引用 (listing_shared / my_questions), 未消完
- 4 个 Tab 5 字漂 bug 最低成本 fix (SizedBox.shrink FAB), 根因未深究
- dashboard_screen / transaction_confirm 独立页面重做留待 V2

## 回滚指南
- 完整回退到批次 1 起点：git reset --hard bc9907b
- 仅回退 theme 引用：main.dart 取消注释原 theme，注释掉 MlsTheme.light

## 跨 session 交接
任何新的 Claude Code session 接手时，先读本文件再读 _incoming/（如有）。

铁律：
- 本文件由你（Claude Code）维护，每完成一个批次或重大变更时更新
- 表格里的 commit 列由我（磊）确认 commit 后告诉你写入，你不要自己猜
- 不要 git add / git commit 本文件，由我手动操作
