import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 徽章语义变体
///
/// 每个变体定义 (背景色, 文字色) 两件套, 控制业务里散落的"小色块文字"统一感
enum MlsBadgeVariant {
  /// 蓝 - 信息 / 已确认 / SCHEDULED
  info,

  /// 绿 - 成功 / 在线 / SECURED
  success,

  /// 橙 - 警告 / 即将到期
  warning,

  /// 红 - 紧急 / PRIORITY HIGH / 驳回
  danger,

  /// 金 - 奖金 / PR / 等级 / 单月新高
  gold,

  /// 灰 - 中性 / 默认 / 待确认
  neutral,

  /// 反白 - 用于深色面板上 (反作弊基石内嵌)
  onDark,
}

/// 徽章尺寸
///
/// - [normal]: 正常 (默认), 字号 11px, padding 3x7
/// - [dense]:  紧凑, 字号 9-10px, padding 2x5, 用于 mono 大写标签 (PRIORITY · HIGH)
enum MlsBadgeSize { normal, dense }

/// MLS 状态徽章 V1
///
/// 用于表达状态/优先级/标签的小色块。可选 leading icon + dot。
///
/// 用法:
/// ```
/// MlsStatusBadge(text: '已结单', variant: MlsBadgeVariant.neutral)
/// MlsStatusBadge(text: '在线', variant: MlsBadgeVariant.success, showDot: true)
/// MlsStatusBadge(text: 'PRIORITY · HIGH',
///                variant: MlsBadgeVariant.danger,
///                size: MlsBadgeSize.dense,
///                mono: true)
/// MlsStatusBadge(text: '已加密', icon: Icons.lock_outline, ...)
/// ```
class MlsStatusBadge extends StatelessWidget {
  final String text;
  final MlsBadgeVariant variant;
  final MlsBadgeSize size;

  /// 是否用 mono 字体 (大写英文标签如 LIVE / PRIORITY · HIGH 都用 mono)
  final bool mono;

  /// 前置 icon (icon 在文字左边)
  final IconData? icon;

  /// 前置色点 (与 icon 二选一; 同传时 icon 优先)
  final bool showDot;

  const MlsStatusBadge({
    super.key,
    required this.text,
    this.variant = MlsBadgeVariant.neutral,
    this.size = MlsBadgeSize.normal,
    this.mono = false,
    this.icon,
    this.showDot = false,
  });

  ({Color bg, Color fg, Color? border}) _resolveColors() {
    switch (variant) {
      case MlsBadgeVariant.info:
        return (bg: MlsColors.primaryBg, fg: MlsColors.primary, border: null);
      case MlsBadgeVariant.success:
        return (bg: MlsColors.successBg, fg: const Color(0xFF047857), border: null);
      case MlsBadgeVariant.warning:
        return (
          bg: MlsColors.warningBg,
          fg: const Color(0xFF92400E),
          border: null
        );
      case MlsBadgeVariant.danger:
        return (bg: MlsColors.dangerBg, fg: MlsColors.danger, border: null);
      case MlsBadgeVariant.gold:
        return (
          bg: MlsColors.goldBgEnd,
          fg: MlsColors.goldTextDark,
          border: null,
        );
      case MlsBadgeVariant.neutral:
        return (
          bg: const Color(0x0F0F172A), // 6% black
          fg: MlsColors.textSecondary,
          border: null,
        );
      case MlsBadgeVariant.onDark:
        return (
          bg: const Color(0x1A22C55E), // 10% green
          fg: const Color(0xFF86EFAC),
          border: const Color(0x4D22C55E), // 30% green
        );
    }
  }

  TextStyle _resolveTextStyle(Color fg) {
    final dense = size == MlsBadgeSize.dense;
    if (mono) {
      return dense
          ? MlsTypography.monoStatusLabel(fg)
          : MlsTypography.monoBadge.copyWith(color: fg);
    }
    return TextStyle(
      fontFamilyFallback: MlsTypography.sansFallback,
      fontSize: dense ? 10 : 11,
      fontWeight: MlsTypography.medium,
      color: fg,
      height: 1.2,
    );
  }

  EdgeInsets _resolvePadding() {
    return size == MlsBadgeSize.dense
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 7, vertical: 3);
  }

  double _resolveIconSize() {
    return size == MlsBadgeSize.dense ? 11 : 12;
  }

  @override
  Widget build(BuildContext context) {
    final c = _resolveColors();
    final ts = _resolveTextStyle(c.fg);
    final pad = _resolvePadding();
    final iconSize = _resolveIconSize();
    final children = <Widget>[];

    if (icon != null) {
      children.add(Icon(icon, size: iconSize, color: c.fg));
      children.add(const SizedBox(width: 4));
    } else if (showDot) {
      children.add(Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.fg),
      ));
      children.add(const SizedBox(width: 5));
    }
    children.add(Text(text, style: ts));

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: MlsRadius.badge,
        border: c.border != null
            ? Border.all(color: c.border!, width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
