import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

class MlsMedalInline extends StatelessWidget {
  final IconData icon;
  final int iconCount;
  final Color iconColor;
  final String label;
  final String valueText;
  final String? subtitle;
  final bool dark;

  const MlsMedalInline({
    super.key,
    required this.icon,
    required this.iconCount,
    required this.iconColor,
    required this.label,
    required this.valueText,
    this.subtitle,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final onDarkMuted = dark ? Colors.white54 : MlsColors.textSecondary;
    final onDarkSubtle = dark ? Colors.white38 : MlsColors.textTertiary;
    final onDark = dark ? Colors.white : MlsColors.textPrimary;

    final count = iconCount.clamp(1, 3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withValues(alpha: 0.15),
            border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(count, (i) {
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 1, right: 1),
                child: Icon(icon, size: count == 1 ? 16 : 12, color: iconColor),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: MlsTypography.monoLabel.copyWith(color: onDarkSubtle)),
              const SizedBox(height: 2),
              Text(valueText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: MlsTypography.monoLarge.copyWith(color: onDark)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: MlsTypography.caption1.copyWith(color: onDarkMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}