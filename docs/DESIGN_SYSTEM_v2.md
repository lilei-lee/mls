# MLS Design System v2.0 · "立体科技 · 商家工具"

> 版本: v2.0 | 日期: 2026-05-13 | 替代 v1.0

---

## 设计哲学

✓ 立体 · 科技 · 商务 · 醒目

气质参考（中和）：招商银行 App（金融信任 + 数字大字 + 头部 hero）+ 小红书商家版（卡片质感 + 状态活泼）+ 理想 App（立体卡片 + 大留白 + 信息密）

反例：钉钉/飞书（太工具）、贝壳/链家（太 C 端）

---

## 色板 · 双主色

### 主品牌色 — 科技深蓝

| Token | Hex | 用途 |
|---|---|---|
| Primary 50 | `#E6EDFF` | 弱强调底 / Chip 选中底 |
| Primary 100 | `#CCD9FF` | |
| Primary 500 | `#2E5BFF` | 主品牌色（按钮/Tab/链接） |
| Primary 600 | `#1E47E8` | 按下/悬停 |
| Primary 900 | `#0F1F66` | 深色文字强调 |

### 辅品牌色 — 财富金（用于"钱"相关）

| Token | Hex | 用途 |
|---|---|---|
| Gold 50 | `#FFF9E6` | 奖金卡渐变上 |
| Gold 500 | `#F5A623` | 奖金/成交/达成 |
| Gold 600 | `#E0941A` | 按下 |

### 中性色 10 阶

| Token | Hex | 用途 |
|---|---|---|
| N0 | `#FFFFFF` | Surface 0（页面底） |
| N50 | `#F8FAFC` | Surface 1（section 分隔） |
| N100 | `#EEF1F5` | Surface 2（输入框底） |
| N150 | `#E2E7EE` | 弱边框 |
| N200 | `#CDD3DC` | 分隔线 |
| N300 | `#A8B0BD` | 禁用/占位 |
| N500 | `#6B7280` | 辅助文字 |
| N700 | `#374151` | 次要正文 |
| N800 | `#1F2937` | 正文 |
| N900 | `#0B1220` | 标题强调 |

### 功能色

| Token | Hex | 用途 |
|---|---|---|
| Success | `#10B981` | 已成交/在售 |
| Warning | `#F59E0B` | 待审/已带看 |
| Danger | `#EF4444` | 拒绝/下架 |
| Info | `#3B82F6` | 已通过 |

### 点缀色（仅渐变/装饰）

| Token | Hex |
|---|---|
| Accent Purple | `#8B5CF6` |
| Accent Cyan | `#06B6D4` |

---

## Surface 层级系统（3 层立体感）

| 层级 | 底色 | 阴影 | 用途 |
|---|---|---|---|
| Surface 0 | N0 | 无 | 页面底色 |
| Surface 1 | N50 | 无 | section/卡片底 |
| Surface 2 | N0 | Shadow 1 | 浮起卡片 |
| Surface 3 | N0 | Shadow 2 | 悬浮元素 |

规则：同屏可同时存在 Surface 0/1/2。关键卡片用 Surface 2，普通信息卡用 Surface 1。

---

## 阴影系统

| Token | 定义 | 用途 |
|---|---|---|
| Shadow Hero | `0 8 24 rgba(46,91,255,0.12)` + `0 2 8 rgba(15,31,102,0.06)` | 头部 hero 卡/价格主卡 |
| Shadow Gold | `0 8 24 rgba(245,166,35,0.16)` + `0 2 8 rgba(224,148,26,0.08)` | 奖金卡 |
| Shadow Card | `0 1 3 rgba(11,18,32,0.04)` + `0 4 12 rgba(11,18,32,0.04)` | 普通卡片 |
| Shadow Float | `0 8 32 rgba(11,18,32,0.10)` | BottomSheet/Dialog |
| Shadow Btn | `0 2 6 rgba(46,91,255,0.20)` | 主按钮 |

---

## 渐变系统

| 渐变 | 定义 | 用途 |
|---|---|---|
| Gradient Primary | `linear-gradient(135deg, #2E5BFF 0%, #5478FF 100%)` | 头部 hero / 主 CTA |
| Gradient Gold | `linear-gradient(135deg, #F5A623 0%, #FFB949 100%)` | 奖金卡 / 成交达成 |
| Gradient Surface | `linear-gradient(180deg, #FFF 0%, #F8FAFC 100%)` | section 弱渐变 |

仅在指定场景使用。禁止全屏背景渐变、彩虹色。

---

## 字号系统

字体栈：`-apple-system, "PingFang SC", "Microsoft YaHei", sans-serif`
数字字体（tabular-nums）：`"SF Pro Display", system-ui`

| Token | 尺寸 | 行高 | 字重 | 用途 |
|---|---|---|---|---|
| Display | 28sp | 36 | 700 | 页面 hero 标题 |
| Title L | 22sp | 30 | 700 | AppBar 主标题 |
| Title M | 17sp | 24 | 600 | Section 标题 |
| Title S | 15sp | 22 | 600 | 小标题 |
| Body L | 15sp | 22 | 400 | 主要正文 |
| Body M | 14sp | 20 | 400 | 次要正文（默认） |
| Body S | 13sp | 18 | 400 | 辅助说明 |
| Caption | 12sp | 16 | 500 | Chip/标签/时间戳 |

数字专属（tabular-nums）：

| Token | 尺寸 | 行高 | 字重 | 用途 |
|---|---|---|---|---|
| Number XL | 32sp | 40 | 700 | 价格大字 / hero 数字 |
| Number L | 24sp | 32 | 700 | 统计数字 |
| Number M | 18sp | 24 | 600 | 卡片数字 |

---

## 间距（8dp 网格）

| Token | 值 |
|---|---|
| Space 4 | 4px |
| Space 8 | 8px |
| Space 12 | 12px |
| Space 16 | 16px |
| Space 20 | 20px |
| Space 24 | 24px |
| Space 32 | 32px |
| Space 48 | 48px |

卡片内边距 16-20，section 间 24-32，页面边距 16。

---

## 圆角（放大，更现代）

| Token | 值 | 用途 |
|---|---|---|
| Radius S | 6 | Chip/标签 |
| Radius M | 12 | 按钮/输入框/卡片 |
| Radius L | 16 | Hero 卡/价格卡/奖金卡 |
| Radius XL | 20 | BottomSheet/Dialog |
| Radius Pill | 999 | 胶囊按钮/头像 |

---

## 图标系统

库：Lucide（`lucide_icons` Flutter 包）
风格：统一 outlined 线性，不混 filled
尺寸：16px inline / 20px 按钮内 / 24px AppBar / 32px hero / 48px 空态

禁止：emoji、Material filled 风格、自定义 icon 字体

---

## 组件库 v2.0

### AppBar
高 56，白底，Title L，可选下方滚动渐变阴影

### 主按钮 Primary
高 48，圆角 M(12)，Gradient Primary 渐变底，白字 Title S，Shadow Btn

### 次按钮 Secondary
高 48，圆角 M，白底 + N150 边框，N800 字

### 危险按钮
高 48，圆角 M，白底 + Danger 边框，Danger 字

### 主 CTA Gold
Gradient Gold 渐变底，白字 Title S，Shadow Gold

### 输入框
高 48，圆角 M，N100 底。聚焦：N0 底 + Primary 边框 2px

### Chip
高 30，圆角 S(6)，N100 底，Caption N700
选中：Primary 50 底 + Primary 字 + Primary 边框

### Chip 状态徽标
高 24，圆角 S，功能色 12%底 + 功能色字，Caption

### 卡片 AppCard — 3 种
- **Card Base**: Surface 1/2，圆角 M，N150 边框或 Shadow Card，内边距 16-20
- **Card Hero**: Surface 2，圆角 L(16)，Gradient Primary 或白底，Shadow Hero，内边距 24
- **Card Gold**: Gradient Gold 底，圆角 L(16)，Shadow Gold，内边距 20

### Section 容器
标题 Title M N900，可选右侧链接 Caption Primary，标题与卡片间距 12，section 间 24

### Badge 数字
圆形 Pill，Danger 底白字，18×18 最小，字号 11

### 头像 Avatar
圆形 N100 底，首字 Caption N700。支持彩色（hash 取 Primary/Gold/Cyan/Purple）+ status dot

### 空态 Empty
插画 80px（SVG 线性 + Primary 50 底色圆），Title S N700 + Body M N500 + CTA Primary

### Loading
N100 底 + 渐变流光动画，圆角对应原元素

### Tab Bar 顶部
选中 Primary 字 + 下划线 Primary 2px + 加粗。未选中 N500

### 底部 Tab Bar
N0 底 + 顶部 N150 1px，选中 Primary，未选中 N500，图标 24px outlined

---

## 应用铁律

### ✅
- 头部 hero 区必有视觉锚点（渐变卡/大数字/大头像）
- 数字一律 tabular-nums + Number 字号
- 主按钮 Gradient Primary + 微阴影
- 奖金/成交场景 Gold 渐变
- Surface 层级清晰（同屏 ≥2 层）
- 图标统一 Lucide outlined
- 大圆角（12+）

### ❌
- emoji 装饰
- 灰色矩形占位图
- 全平铺无层次
- 圆角混用
- 字号自由发挥
- banner/大面积彩色铺底
- 渐变滥用（只在指定场景）
- 阴影泛滥（只在 hero/卡片浮起/按钮）

---

## 版本历史

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-13 | 初始版本（已归档） |
| v2.0 | 2026-05-13 | 双主色 + Surface 3 层 + 渐变系统 + 阴影 5 级 + 大圆角 + Lucide 图标 |
