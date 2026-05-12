import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// MLS Section Header V1
///
/// 用于一组内容的标题栏。标题居左, 可选右侧 trailing 槽位 + 标题旁徽章。
///
/// 用法:
/// ```
/// MlsSectionHeader(title: '待办')
/// MlsSectionHeader(title: '待办', badge: '2', badgeVariant: MlsBadgeVariant.danger)
/// MlsSectionHeader(title: '实时动态', trailingLabel: 'FEED · 24H')
/// MlsSectionHeader(title: '协作中', trailing: Row(...))  // 自定义右侧
/// ```
class MlsSectionHeader extends StatelessWidget {
  /// 中文 sans w600 标题
  final String title;

  /// 标题左侧前置 icon (可选)
  final IconData? leadingIcon;

  /// 标题旁的小徽章文字 (如待办数 "2")
  /// 通常配合 badgeBackground / badgeForeground 用语义色
  final String? badge;

  /// 徽章背景色
  final Color? badgeBackground;

  /// 徽章文字色
  final Color? badgeForeground;

  /// 右侧 mono 大写标签 (如 PENDING · 2)
  /// 与 trailing 二选一; 同传时 trailing 优先
  final String? trailingLabel;

  /// 右侧完全自定义 widget (如 SEE ALL ↗ 链接)
  final Widget? trailing;

  /// 内边距 (默认 仅左右 2)
  final EdgeInsetsGeometry padding;

  /// 与下方内容的间距 (默认 8)
  final double bottomSpacing;

  const MlsSectionHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.badge,
    this.badgeBackground,
    this.badgeForeground,
    this.trailingLabel,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
    this.bottomSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final leftItems = <Widget>[];

    if (leadingIcon != null) {
      leftItems.add(Icon(
        leadingIcon,
        size: 14,
        color: MlsColors.textPrimary,
      ));
      leftItems.add(const SizedBox(width: 6));
    }

    leftItems.add(Text(title, style: MlsTypography.sectionTitle));

    if (badge != null) {
      leftItems.add(const SizedBox(width: 6));
      leftItems.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: badgeBackground ?? MlsColors.dangerBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badge!,
          style: MlsTypography.monoBadge.copyWith(
            color: badgeForeground ?? MlsColors.danger,
            fontWeight: MlsTypography.semibold,
            fontSize: 10,
          ),
        ),
      ));
    }

    final rightWidget = trailing ??
        (trailingLabel != null
            ? Text(trailingLabel!, style: MlsTypography.monoLabel)
            : null);

    return Padding(
      padding: padding.add(EdgeInsets.only(bottom: bottomSpacing)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...leftItems,
          const Spacer(),
          if (rightWidget != null) rightWidget,
        ],
      ),
    );
  }
}
