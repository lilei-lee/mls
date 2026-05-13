import 'package:flutter/material.dart';
import '../theme/mls_typography.dart';
import '../theme/mls_colors.dart';
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
            decoration: BoxDecoration(color: MlsColors.primaryBg, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: MlsColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: MlsTypography.sectionTitle.copyWith(color: MlsColors.textPrimary)),
          if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: MlsTypography.body2.copyWith(color: MlsColors.textSecondary), textAlign: TextAlign.center)],
          if (actionLabel != null && onAction != null) ...[const SizedBox(height: 16), AppButton.primary(actionLabel!, onPressed: onAction, height: 40)],
        ]),
      ),
    );
  }
}
