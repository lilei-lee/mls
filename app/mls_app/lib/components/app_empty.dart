import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class AppEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmpty({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppTheme.primary50, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppTheme.primary500),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTheme.titleS.copyWith(color: AppTheme.n700)),
          if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: AppTheme.bodyM.copyWith(color: AppTheme.n500), textAlign: TextAlign.center)],
          if (actionLabel != null && onAction != null) ...[const SizedBox(height: 16), AppButton.primary(actionLabel!, onPressed: onAction, height: 40)],
        ]),
      ),
    );
  }
}
