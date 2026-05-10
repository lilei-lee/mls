# MLS Design System v1.0

> 版本: v1.0 | 日期: 2026-05-13 | 状态: 原型阶段

---

## 设计哲学

专业 B2B SaaS（非 C 端房产 App）。参考气质：飞书 / Notion / Linear / 招商银行 App。反例：贝壳/链家（banner 多/促销红/C 端导购感强）。

四个关键词：**克制 · 清晰 · 信任 · 高效**

---

## 色板

### 品牌色

| Token | Hex | 用途 |
|---|---|---|
| Primary | `#1E5EFF` | 主按钮 / Tab 选中 / 链接 |
| Primary Dark | `#1748D9` | 按下态 / 悬停 |
| Primary 50 | `#EBF1FF` | Chip 选中底 / 弱强调背景 |

### 中性色 9 阶

| Token | Hex | 用途 |
|---|---|---|
| N0 | `#FFFFFF` | 页面底 |
| N50 | `#F7F8FA` | Section 分隔 / 卡片底色 1 |
| N100 | `#EEF0F4` | 输入框底 / Chip 默认底 |
| N200 | `#E2E5EB` | 分隔线 / 边框 |
| N300 | `#C8CDD6` | 禁用文字 / 占位文字 |
| N500 | `#8B92A0` | 辅助说明文字 |
| N700 | `#4A5160` | 次要正文 |
| N800 | `#2D333E` | 正文 |
| N900 | `#14181F` | 标题强调 |

### 功能色 — 仅状态使用

| Token | Hex | 用途 |
|---|---|---|
| Success | `#00B578` | 已成交 / 成功 / 在售 |
| Warning | `#FF8B1F` | 待处理 / 橙提醒 |
| Danger | `#F5454A` | 拒绝 / 错误 / 下架 |
| Info | `#2E7CF6` | 已通过 / 信息 |
| Locked | `#8B92A0` | 未解锁（用 N500） |

### 协作状态色映射 — 严禁互换

| 状态 | 颜色 | Token |
|---|---|---|
| 待审核 | `#FF8B1F` | Warning |
| 已通过 | `#2E7CF6` | Info |
| 已带看 | `#1E5EFF` | Primary |
| 已发起成交 | `#D96A0F` | Warning Dark |
| 已成交 | `#00B578` | Success |
| 已拒绝 | `#8B92A0` | N500 |

---

## 字号系统

字体栈：`-apple-system, "PingFang SC", "Microsoft YaHei", sans-serif`

| Token | 尺寸 | 行高 | 字重 | 用途 |
|---|---|---|---|---|
| Display | 24sp | 32 | 700 | 页面大标题（罕用） |
| Title L | 20sp | 28 | 600 | AppBar 主标题 |
| Title M | 16sp | 24 | 600 | Section 标题 / 卡片标题 |
| Title S | 14sp | 20 | 600 | 小标题 / 强调 |
| Body L | 15sp | 22 | 400 | 主要正文 |
| Body M | 14sp | 20 | 400 | 次要正文（默认） |
| Body S | 13sp | 18 | 400 | 辅助说明 |
| Caption | 12sp | 16 | 400 | Chip 文字 / 角标 / 时间戳 |
| Number L | 28sp | 36 | 600 | 价格大字 |
| Number M | 18sp | 24 | 600 | 统计数字 |

---

## 间距（8dp 网格，严格执行）

| Token | 值 | 用途 |
|---|---|---|
| Space 4 | 4px | 细微调 |
| Space 8 | 8px | 组件内部 |
| Space 12 | 12px | 紧凑卡片内 |
| Space 16 | 16px | 默认间距（用得最多） |
| Space 24 | 24px | Section 之间 |
| Space 32 | 32px | 大段落分隔 |

---

## 圆角（3 档语义）

| Token | 值 | 用途 |
|---|---|---|
| Radius S | 4px | Chip / 标签 / 小角标 |
| Radius M | 8px | 按钮 / 输入框 / 卡片 |
| Radius L | 16px | Bottom Sheet / Dialog |

---

## 阴影（克制使用）

| Token | 值 | 用途 |
|---|---|---|
| Shadow 0 | 无 | 默认（用 N200 边框分隔） |
| Shadow 1 | `0 1 2 rgba(20,24,31,0.04)` | 悬浮卡片 |
| Shadow 2 | `0 4 12 rgba(20,24,31,0.08)` | 弹窗 |

原则：能用边框分隔就别用阴影，B2B App 阴影泛滥显廉价。

---

## 组件库规范

### AppBar
- 高度 56px，白底，Title L 居中或左对齐
- 返回箭头 24px，N800
- 右侧 actions 24px icon，N700

### 主按钮 Primary Button
- 高 44px，圆角 M(8)，Primary 底，白字 Title S
- 禁用态：N300 底，白字
- 按下：Primary Dark

### 次按钮 Secondary Button
- 高 44px，圆角 M，白底 + N200 边框，N800 字 Title S
- 按下：N50 底

### 危险按钮 Danger Button
- 高 44px，圆角 M，白底 + Danger 边框，Danger 字
- 按下：Danger 浅底

### 输入框 Input
- 高 44px，圆角 M，N100 底，无边框
- 聚焦：N0 底 + Primary 边框
- 错误：Danger 边框 + Danger 错误文字 Body S

### Chip 默认
- 高 28px，圆角 S(4)，N100 底，Body S N700 字
- 选中：Primary 50 底，Primary 字，Primary 边框

### Chip 状态徽标
- 高 22px，圆角 S，功能色 10%底 + 功能色字
- 例：已通过 = `#2E7CF6` + 透明度 15% 底

### 卡片 AppCard
- 圆角 M，白底，N200 边框 1px，无阴影
- 内边距 Space 16
- hover/press：N50 底

### Section 容器
- Section 标题 Title M，N900，左对齐
- Section 内卡片堆叠，Space 12 间隔
- Section 之间 Space 24

### 分隔线
- N200，1px，左右无边距（贯穿）
- 弱分隔：N100，1px

### 空态 Empty
- 居中，图标 48px N300
- 主文 Title S N700，辅文 Body M N500
- CTA 主按钮 Primary

### Loading（骨架屏）
- N100 底色 + 微动画
- 小型：CircularProgress 24px Primary

### 错误 Error
- 图标 24px Danger
- 主文 Title S N800，辅文 Body M N500
- 重试按钮 Secondary

---

## 应用规则（严格）

### ✅ 必须
- 大面积白（N0）+ 浅灰（N50/N100）
- 文字层级用色阶（N900/N800/N700/N500）
- 功能色只在状态/数字/CTA 出现，不做装饰
- 一个屏幕主色不超 1 处（主按钮 OR 选中 Tab）
- 图标统一 outlined 风格，不混 filled

### ❌ 禁止
- 禁用渐变（gradient）
- 禁用彩色 emoji 装饰
- 禁用 amber/红色/绿色作为底色大面积铺
- 禁止圆角混用，只允许 4/8/16 三档
- 禁止字号自由发挥，只允许定义的 9 档

---

## 页面骨架

```
┌─────────────────────────────────┐
│ Status Bar (系统)               │
├─────────────────────────────────┤
│ AppBar 56px (Title L / N0 底)   │
├─────────────────────────────────┤
│                                 │
│ Scroll Body                     │
│   Section (Space 24 gap)        │
│     Title M N900                │
│     Card M radius / N200 border │
│       Space 16 pad              │
│                                 │
├─────────────────────────────────┤
│ Bottom Nav 56px (N0 + N200 top) │
│ OR Fixed Action Bar             │
└─────────────────────────────────┘
```

---

## 版本历史

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-13 | 初始版本，5 色板 + 9 字号 + 3 圆角 + 8 组件 |
