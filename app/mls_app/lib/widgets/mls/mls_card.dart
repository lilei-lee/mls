import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_shadows.dart';

/// 卡片视觉变体
///
/// - [primary]: 白渐变 + 中等阴影 (默认, 用于普通卡片)
/// - [elevated]: 白渐变 + 强阴影 (用于焦点卡片, 如 4-metric panel)
/// - [dark]: 深色面板 + 深色阴影 (用于反作弊基石 / 等级卡片 / 严肃区)
/// - [gold]: 暖橙金渐变 + 金色光晕 (用于奖金区)
/// - [hero]: 蓝色渐变 + 蓝色光晕 (用于 Hero Today 倒计时大卡片)
/// - [flat]: 纯白 + 极轻阴影 (用于列表项 / 紧凑卡片)
enum MlsCardVariant {
  primary,
  elevated,
  dark,
  gold,
  hero,
  flat,
}

/// MLS 立体卡片 V1
///
/// 封装"白卡渐变 + 多层阴影 + 圆角 + 内边距 + 边框"五件套, 一行 API 替代
/// 业务里散落的 BoxDecoration 模板代码。
///
/// 业务用法:
/// ```
/// MlsCard(child: Text('普通卡片'))
/// MlsCard(variant: MlsCardVariant.gold, child: ...)  // 奖金区
/// MlsCard(variant: MlsCardVariant.dark, child: ...)  // 反作弊基石
/// MlsCard(onTap: () => ..., child: ...)              // 可点击
/// ```
///
/// 设计约束:
/// - 业务代码不要再写 BoxDecoration + boxShadow + gradient 这套, 走 MlsCard 即可
/// - 如需特殊定制, 用 backgroundColor / gradient / boxShadow 参数覆盖,
///   不要绕开 MlsCard 直接写 Container
class MlsCard extends StatefulWidget {
  /// 卡片内容
  final Widget child;

  /// 视觉变体 (默认 primary)
  final MlsCardVariant variant;

  /// 自定义内边距 (默认根据 variant 智能选)
  final EdgeInsetsGeometry? padding;

  /// 外边距 (默认 0, 由父组件负责间距)
  final EdgeInsetsGeometry? margin;

  /// 点击回调; 非空时启用按下反馈 (轻微 scale 0.98)
  final VoidCallback? onTap;

  /// 自定义圆角 (默认 cardLg = 16; flat = card = 14)
  final BorderRadius? borderRadius;

  /// 自定义边框色 (默认 borderLight; dark variant 时为 borderOnDark)
  final Color? borderColor;

  /// 自定义边框宽度 (默认 0.5)
  final double borderWidth;

  /// 覆盖背景色 (传了就用纯色不用渐变)
  final Color? backgroundColor;

  /// 覆盖渐变 (优先级高于 variant 默认)
  final Gradient? gradient;

  /// 覆盖阴影 (优先级高于 variant 默认)
  final List<BoxShadow>? boxShadow;

  const MlsCard({
    super.key,
    required this.child,
    this.variant = MlsCardVariant.primary,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 0.5,
    this.backgroundColor,
    this.gradient,
    this.boxShadow,
  });

  @override
  State<MlsCard> createState() => _MlsCardState();
}

class _MlsCardState extends State<MlsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Gradient? _resolveGradient() {
    if (widget.gradient != null) return widget.gradient;
    if (widget.backgroundColor != null) return null;
    switch (widget.variant) {
      case MlsCardVariant.primary:
      case MlsCardVariant.elevated:
        return MlsColors.cardElevated;
      case MlsCardVariant.dark:
        return MlsColors.panelDark;
      case MlsCardVariant.gold:
        return MlsColors.goldBg;
      case MlsCardVariant.hero:
        return MlsColors.heroBlue;
      case MlsCardVariant.flat:
        return null;
    }
  }

  Color? _resolveBackgroundColor() {
    if (widget.backgroundColor != null) return widget.backgroundColor;
    if (_resolveGradient() != null) return null;
    return MlsColors.bgCardPrimary;
  }

  List<BoxShadow> _resolveShadow() {
    if (widget.boxShadow != null) return widget.boxShadow!;
    switch (widget.variant) {
      case MlsCardVariant.primary:
        return MlsShadows.md;
      case MlsCardVariant.elevated:
        return MlsShadows.lg;
      case MlsCardVariant.dark:
        return MlsShadows.panelDark;
      case MlsCardVariant.gold:
        return MlsShadows.goldGlow;
      case MlsCardVariant.hero:
        return MlsShadows.heroBlue;
      case MlsCardVariant.flat:
        return MlsShadows.sm;
    }
  }

  BorderRadius _resolveBorderRadius() {
    if (widget.borderRadius != null) return widget.borderRadius!;
    return widget.variant == MlsCardVariant.flat
        ? MlsRadius.card
        : MlsRadius.cardLg;
  }

  EdgeInsetsGeometry _resolvePadding() {
    if (widget.padding != null) return widget.padding!;
    return widget.variant == MlsCardVariant.flat
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
        : const EdgeInsets.all(14);
  }

  Color _resolveBorderColor() {
    if (widget.borderColor != null) return widget.borderColor!;
    return widget.variant == MlsCardVariant.dark
        ? MlsColors.borderOnDark
        : MlsColors.borderLight;
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final cardChild = Container(
      decoration: BoxDecoration(
        color: _resolveBackgroundColor(),
        gradient: _resolveGradient(),
        borderRadius: _resolveBorderRadius(),
        border: Border.all(
          color: _resolveBorderColor(),
          width: widget.borderWidth,
        ),
        boxShadow: _resolveShadow(),
      ),
      padding: _resolvePadding(),
      child: widget.child,
    );

    final wrappedChild = widget.margin != null
        ? Padding(padding: widget.margin!, child: cardChild)
        : cardChild;

    if (!tappable) return wrappedChild;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scaleAnimation, child: wrappedChild),
    );
  }
}
