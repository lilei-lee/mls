import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final _CardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard._({required this.child, required this.variant, this.padding = const EdgeInsets.all(16), this.onTap});

  const AppCard.base({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), VoidCallback? onTap})
      : this._(child: child, variant: _CardVariant.base, padding: padding, onTap: onTap);

  const AppCard.hero({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20), VoidCallback? onTap})
      : this._(child: child, variant: _CardVariant.hero, padding: padding, onTap: onTap);

  const AppCard.gold({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20), VoidCallback? onTap})
      : this._(child: child, variant: _CardVariant.gold, padding: padding, onTap: onTap);

  const AppCard.flat({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), VoidCallback? onTap})
      : this._(child: child, variant: _CardVariant.flat, padding: padding, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: _decoration(),
      child: child,
    );
    if (onTap != null) {
      return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppTheme.radiusM), child: card));
    }
    return card;
  }

  BoxDecoration _decoration() {
    switch (variant) {
      case _CardVariant.base:
        return BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(AppTheme.radiusM), boxShadow: AppTheme.shadowCard);
      case _CardVariant.hero:
        return BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(AppTheme.radiusL), boxShadow: AppTheme.shadowHero);
      case _CardVariant.gold:
        return BoxDecoration(borderRadius: BorderRadius.circular(AppTheme.radiusL), gradient: AppTheme.gradientGold, boxShadow: AppTheme.shadowGold);
      case _CardVariant.flat:
        return BoxDecoration(color: AppTheme.surface1, borderRadius: BorderRadius.circular(AppTheme.radiusM));
    }
  }
}

enum _CardVariant { base, hero, gold, flat }
