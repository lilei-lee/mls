# MLS 视觉规范 V1 · 风格规约

## 强制规则

### 颜色
- 唯一来源: MlsColors.* (lib/theme/mls_colors.dart)
- 禁: Colors.* (除 Colors.white / Colors.transparent / Colors.black 兜底场景)
- 禁: Color(0xFF...) 直接字面量 (除 alpha 调整)

### 字号 / TextStyle
- 唯一来源: MlsTypography.* (lib/theme/mls_typography.dart)
- 禁: TextStyle(fontSize: X) 直接字面量 (除 size 来自局部计算)

### 圆角
- 优先: MlsRadius.* (lib/theme/mls_radius.dart)
- 备选: 字面量数字 (4.0 / 8.0 / 12.0 / 16.0 / 20.0)

### 卡片
- 必须: MlsCard (lib/widgets/mls/mls_card.dart)
- 禁: Card / Material widget Card (除 BottomSheet 内部)

### 头像
- 必须: MlsAvatar (lib/widgets/mls/mls_avatar.dart)
- 禁: CircleAvatar 直接使用

### Badge / 状态徽章
- 必须: MlsStatusBadge (lib/widgets/mls/mls_status_badge.dart)
- 禁: Container + BoxDecoration 自撕小色块

### Section 标题
- 必须: MlsSectionHeader (lib/widgets/mls/mls_section_header.dart)

### 阴影
- 唯一来源: MlsShadows.* (lib/theme/mls_shadows.dart)
- 禁: 自撕 BoxShadow

## Tab 页脚必备 (避免 5 字 bug)

每个挂在 MainShell IndexedStack 内的 Scaffold 子页面, 必须有:
  floatingActionButton: FloatingActionButton 或 SizedBox.shrink()

无 FAB 的 Scaffold 在 IndexedStack 嵌套下会触发底部 BottomNav label 文字渗透到 body 顶部. 已知坑.

## 不允许的 import

- import '../theme/app_theme.dart';      ❌ (已删除)
- import '../components/app_card.dart';  ❌ (已删除)
- import '../components/app_avatar.dart';  ❌ (已删除)
- import '../components/app_section.dart';  ❌ (已删除)
