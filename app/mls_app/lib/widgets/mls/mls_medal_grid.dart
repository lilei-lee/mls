import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 等级徽标数据
class MedalLevel {
  final String label;
  final IconData iconData;
  final int iconCount;
  final Color color;
  final String rangeText;

  const MedalLevel({
    required this.label,
    required this.iconData,
    required this.iconCount,
    required this.color,
    required this.rangeText,
  });
}

/// MLS 8 级徽标网格
///
/// 用法:
/// ```
/// MlsMedalGrid(
///   levels: MlsMedalGrid.defaultV6Levels,
///   currentLevel: 2,  // 资深
/// )
/// ```
class MlsMedalGrid extends StatelessWidget {
  final List<MedalLevel> levels;
  final int currentLevel;
  final int crossAxisCount;
  final bool dark;

  const MlsMedalGrid({
    super.key,
    required this.levels,
    required this.currentLevel,
    this.crossAxisCount = 4,
    this.dark = true,
  });

  /// V6 8 级等级默认数据
  static const defaultV6Levels = [
    MedalLevel(
      label: '见习',
      iconData: LucideIcons.key,
      iconCount: 1,
      color: MlsColors.textSecondary,
      rangeText: '0-49',
    ),
    MedalLevel(
      label: '入门',
      iconData: LucideIcons.key,
      iconCount: 2,
      color: MlsColors.success,
      rangeText: '50-149',
    ),
    MedalLevel(
      label: '资深',
      iconData: LucideIcons.key,
      iconCount: 3,
      color: MlsColors.primary,
      rangeText: '150-399',
    ),
    MedalLevel(
      label: '金牌',
      iconData: LucideIcons.home,
      iconCount: 1,
      color: MlsColors.primaryLight,
      rangeText: '400-899',
    ),
    MedalLevel(
      label: '王牌',
      iconData: LucideIcons.home,
      iconCount: 2,
      color: MlsColors.chartPurple,
      rangeText: '900-1999',
    ),
    MedalLevel(
      label: '钻石',
      iconData: LucideIcons.home,
      iconCount: 3,
      color: MlsColors.gold,
      rangeText: '2000-3999',
    ),
    MedalLevel(
      label: '城市之星',
      iconData: LucideIcons.crown,
      iconCount: 1,
      color: MlsColors.goldLight,
      rangeText: '4000-7999',
    ),
    MedalLevel(
      label: '传奇',
      iconData: LucideIcons.crown,
      iconCount: 2,
      color: MlsColors.gold,
      rangeText: '8000+',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final onDark = dark ? Colors.white : MlsColors.textPrimary;
    final onDarkMuted =
        dark ? Colors.white70 : MlsColors.textSecondary;
    final onDarkSubtle =
        dark ? Colors.white38 : MlsColors.textTertiary;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: levels.length,
      itemBuilder: (_, i) {
        final level = levels[i];
        final isActive = i == currentLevel;
        final isAchieved = i < currentLevel;
        final isLocked = i > currentLevel;

        final iconColor = isLocked
            ? onDarkSubtle
            : (isActive ? Colors.white : onDark);
        final bgColor = isLocked
            ? Colors.white.withValues(alpha: 0.05)
            : (isActive
                ? level.color
                : level.color.withValues(alpha: 0.25));
        final borderColor = isActive ? level.color : Colors.white10;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // circle with icons
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(
                  color: borderColor,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: level.color.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: isLocked
                  ? Icon(level.iconData,
                      size: 20, color: onDarkSubtle)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(level.iconCount, (j) {
                        return Padding(
                          padding: EdgeInsets.only(
                              left: j == 0 ? 0 : 1, right: 1),
                          child: Icon(level.iconData,
                              size: 14, color: iconColor),
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 4),
            // label
            Text(
              level.label,
              style: MlsTypography.caption1.copyWith(
                color: isActive ? level.color : onDarkMuted,
                fontWeight:
                    isActive ? MlsTypography.semibold : MlsTypography.regular,
              ),
            ),
            const SizedBox(height: 1),
            // range text
            Text(
              level.rangeText,
              style: MlsTypography.monoTinyLabel.copyWith(
                color: onDarkSubtle,
              ),
            ),
          ],
        );
      },
    );
  }
}
