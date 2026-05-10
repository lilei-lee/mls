import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSection extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  const AppSection({super.key, required this.title, this.actionLabel, this.onAction, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 16), this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: padding,
          child: Row(children: [
            Expanded(child: Text(title, style: AppTheme.titleM)),
            if (actionLabel != null)
              GestureDetector(
                onTap: onAction,
                child: Text(actionLabel!, style: AppTheme.caption.copyWith(color: AppTheme.primary500, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final child in children) ...[Padding(padding: padding, child: child), SizedBox(height: gap)],
      ]),
    );
  }
}
