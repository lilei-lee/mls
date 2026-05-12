import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_shadows.dart';
import '../../theme/mls_typography.dart';

/// 按钮视觉变体
enum MlsButtonVariant {
  /// 蓝渐变 (默认 CTA, 如"立即处理")
  primary,

  /// 深色严肃 (反作弊提交、成交确认)
  dark,

  /// 红渐变 (紧急, 如"立即处理"红色版)
  danger,

  /// 白底彩字 + 边框 (Hero 卡片内嵌的"立即准备")
  outline,

  /// 浅灰底 + 深字 (次要操作, 如"取消")
  secondary,

  /// 透明 + 文字 (最次要)
  text,
}

/// 按钮尺寸
enum MlsButtonSize {
  small, // height 32, font 12, padding 5x12
  normal, // height 40, font 13.5, padding 8x16
  large, // height 48, font 15, padding 12x20
}

/// MLS 主按钮 V1
///
/// 一个组件托管所有按钮场景, 不再用原生 ElevatedButton / OutlinedButton。
///
/// 用法:
/// ```
/// MlsPrimaryButton(text: '立即准备', onPressed: () => ...)
/// MlsPrimaryButton(text: '提交录入', variant: MlsButtonVariant.dark, leadingIcon: Icons.lock_outline, ...)
/// MlsPrimaryButton(text: '立即处理', variant: MlsButtonVariant.danger, trailingIcon: Icons.arrow_forward, ...)
/// MlsPrimaryButton(text: '取消', variant: MlsButtonVariant.secondary, ...)
/// MlsPrimaryButton(text: '...', onPressed: null)  // 禁用态
/// ```
class MlsPrimaryButton extends StatefulWidget {
  /// 按钮文字
  final String text;

  /// 点击回调; null = 禁用
  final VoidCallback? onPressed;

  /// 视觉变体
  final MlsButtonVariant variant;

  /// 尺寸
  final MlsButtonSize size;

  /// 前置 icon
  final IconData? leadingIcon;

  /// 后置 icon (常用箭头)
  final IconData? trailingIcon;

  /// 是否撑满父宽度 (默认 false)
  final bool fullWidth;

  /// loading 态 (显示菊花)
  final bool loading;

  const MlsPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = MlsButtonVariant.primary,
    this.size = MlsButtonSize.normal,
    this.leadingIcon,
    this.trailingIcon,
    this.fullWidth = false,
    this.loading = false,
  });

  @override
  State<MlsPrimaryButton> createState() => _MlsPrimaryButtonState();
}

class _MlsPrimaryButtonState extends State<MlsPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  // ============ 视觉解析 ============

  ({
    Color fg,
    Color? bg,
    Gradient? gradient,
    Color? borderColor,
    List<BoxShadow>? shadow
  }) _resolveStyle() {
    switch (widget.variant) {
      case MlsButtonVariant.primary:
        return (
          fg: Colors.white,
          bg: null,
          gradient: MlsColors.buttonBlue,
          borderColor: null,
          shadow: MlsShadows.primaryButton,
        );
      case MlsButtonVariant.dark:
        return (
          fg: Colors.white,
          bg: null,
          gradient: MlsColors.buttonDark,
          borderColor: null,
          shadow: MlsShadows.darkButton,
        );
      case MlsButtonVariant.danger:
        return (
          fg: Colors.white,
          bg: null,
          gradient: MlsColors.buttonDanger,
          borderColor: null,
          shadow: MlsShadows.dangerButton,
        );
      case MlsButtonVariant.outline:
        return (
          fg: MlsColors.primary,
          bg: MlsColors.bgCardPrimary,
          gradient: null,
          borderColor: MlsColors.primary,
          shadow: [
            const BoxShadow(
              color: Color(0x26000000), // 15% black
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        );
      case MlsButtonVariant.secondary:
        return (
          fg: MlsColors.textPrimary,
          bg: MlsColors.bgCardPrimary,
          gradient: null,
          borderColor: MlsColors.borderStrong,
          shadow: MlsShadows.sm,
        );
      case MlsButtonVariant.text:
        return (
          fg: MlsColors.primary,
          bg: Colors.transparent,
          gradient: null,
          borderColor: null,
          shadow: null,
        );
    }
  }

  ({EdgeInsets padding, double fontSize, double iconSize, double height})
      _resolveSize() {
    switch (widget.size) {
      case MlsButtonSize.small:
        return (
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          fontSize: 12,
          iconSize: 14,
          height: 32,
        );
      case MlsButtonSize.normal:
        return (
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          fontSize: 13.5,
          iconSize: 16,
          height: 40,
        );
      case MlsButtonSize.large:
        return (
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          fontSize: 15,
          iconSize: 18,
          height: 48,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();
    final sz = _resolveSize();
    final disabled = !_enabled;
    final fg = disabled ? style.fg.withOpacity(0.5) : style.fg;

    final children = <Widget>[];
    if (widget.loading) {
      children.add(SizedBox(
        width: sz.iconSize,
        height: sz.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(fg),
        ),
      ));
      children.add(const SizedBox(width: 8));
    } else if (widget.leadingIcon != null) {
      children.add(Icon(widget.leadingIcon, size: sz.iconSize, color: fg));
      children.add(const SizedBox(width: 6));
    }

    children.add(Text(
      widget.text,
      style: TextStyle(
        fontFamilyFallback: MlsTypography.sansFallback,
        fontSize: sz.fontSize,
        fontWeight: MlsTypography.semibold,
        color: fg,
        height: 1,
      ),
    ));

    if (widget.trailingIcon != null && !widget.loading) {
      children.add(const SizedBox(width: 4));
      children.add(Icon(widget.trailingIcon, size: sz.iconSize, color: fg));
    }

    final innerBox = Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        height: sz.height,
        padding: sz.padding,
        decoration: BoxDecoration(
          color: style.bg,
          gradient: style.gradient,
          borderRadius: MlsRadius.button,
          border: style.borderColor != null
              ? Border.all(
                  color: style.borderColor!,
                  width: widget.variant == MlsButtonVariant.outline
                      ? 1.5
                      : 0.5)
              : null,
          boxShadow: disabled ? null : style.shadow,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize:
              widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );

    final wrappedBox = widget.fullWidth
        ? SizedBox(width: double.infinity, child: innerBox)
        : innerBox;

    if (disabled) return wrappedBox;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(scale: _scaleAnimation, child: wrappedBox),
    );
  }
}
