import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final _ButtonVariant variant;
  final double height;
  final bool disabled;

  const AppButton._({required this.label, this.onPressed, required this.variant, this.height = 48, this.disabled = false});

  const AppButton.primary(String label, {VoidCallback? onPressed, double height = 48, bool disabled = false})
      : this._(label: label, onPressed: onPressed, variant: _ButtonVariant.primary, height: height, disabled: disabled);

  const AppButton.secondary(String label, {VoidCallback? onPressed, double height = 48, bool disabled = false})
      : this._(label: label, onPressed: onPressed, variant: _ButtonVariant.secondary, height: height, disabled: disabled);

  const AppButton.danger(String label, {VoidCallback? onPressed, double height = 48, bool disabled = false})
      : this._(label: label, onPressed: onPressed, variant: _ButtonVariant.danger, height: height, disabled: disabled);

  const AppButton.gold(String label, {VoidCallback? onPressed, double height = 48, bool disabled = false})
      : this._(label: label, onPressed: onPressed, variant: _ButtonVariant.gold, height: height, disabled: disabled);

  @override
  Widget build(BuildContext context) {
    final enabled = !disabled && onPressed != null;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: _decoration(enabled),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12.0),
            child: Center(child: Text(label, style: _textStyle(enabled))),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(bool enabled) {
    switch (variant) {
      case _ButtonVariant.primary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          gradient: enabled ? AppTheme.gradientPrimary : null,
          color: enabled ? null : AppTheme.n300,
          boxShadow: enabled ? AppTheme.shadowBtn : null,
        );
      case _ButtonVariant.secondary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: enabled ? MlsColors.bgCardPrimary : AppTheme.n100,
          border: Border.all(color: enabled ? AppTheme.n150 : AppTheme.n200, width: 1.5),
        );
      case _ButtonVariant.danger:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: enabled ? MlsColors.bgCardPrimary : AppTheme.n100,
          border: Border.all(color: AppTheme.danger, width: 1.5),
        );
      case _ButtonVariant.gold:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          gradient: enabled ? AppTheme.gradientGold : null,
          color: enabled ? null : AppTheme.n300,
          boxShadow: enabled ? AppTheme.shadowGold : null,
        );
    }
  }

  TextStyle _textStyle(bool enabled) {
    final base = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    switch (variant) {
      case _ButtonVariant.primary:
      case _ButtonVariant.gold:
        return base.copyWith(color: enabled ? MlsColors.bgCardPrimary : MlsColors.bgCardPrimary);
      case _ButtonVariant.secondary:
        return base.copyWith(color: enabled ? AppTheme.n800 : AppTheme.n300);
      case _ButtonVariant.danger:
        return base.copyWith(color: enabled ? AppTheme.danger : AppTheme.n300);
    }
  }
}

enum _ButtonVariant { primary, secondary, danger, gold }
