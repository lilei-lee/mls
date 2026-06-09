import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 设置行 V1
///
/// 分组卡内行：圆角色图标 + 标题 + 右侧（badge / 开关 / 副文+箭头）。
///
/// 用法:
/// ```dart
/// MlsSettingTile(
///   icon: Icons.home,
///   iconBg: MlsColors.primaryBg,
///   iconFg: MlsColors.primary,
///   title: '我的房源',
///   subtitle: '12 套',
///   onTap: () => ...,
/// )
/// MlsSettingTile.switch(
///   icon: Icons.notifications,
///   title: '消息通知',
///   value: _notif,
///   onChanged: (v) => ...,
/// )
/// ```
class MlsSettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  // 右侧三选一
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailing;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  const MlsSettingTile({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    this.subtitle,
    this.onTap,
    this.badgeText,
    this.badgeColor,
    this.trailing,
    this.switchValue,
    this.onSwitchChanged,
  });

  /// 工厂：带开关的设置行
  factory MlsSettingTile.switchTile({
    Key? key,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      MlsSettingTile(
        key: key,
        icon: icon,
        iconBg: iconBg,
        iconFg: iconFg,
        title: title,
        subtitle: subtitle,
        switchValue: value,
        onSwitchChanged: onChanged,
      );

  /// 工厂：带副文+箭头的设置行
  factory MlsSettingTile.link({
    Key? key,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) =>
      MlsSettingTile(
        key: key,
        icon: icon,
        iconBg: iconBg,
        iconFg: iconFg,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: switchValue != null ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamilyFallback: MlsTypography.sansFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MlsColors.textPrimary,
                ),
              ),
            ),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? MlsColors.successBg,
                  borderRadius: MlsRadius.badge,
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor ?? MlsColors.success,
                  ),
                ),
              )
            else if (switchValue != null)
              GestureDetector(
                onTap: () => onSwitchChanged?.call(!switchValue!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: switchValue! ? MlsColors.primary : MlsColors.borderStrong,
                  ),
                  alignment: switchValue! ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else ...[
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: MlsTypography.caption1,
                ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: MlsColors.textTertiary),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
