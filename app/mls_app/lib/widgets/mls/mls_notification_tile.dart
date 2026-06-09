import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';
import 'mls_card.dart';

/// 通知单项 V1
///
/// 圆形色图标 + 标题/副文 + 未读红点 + 时间 + 可选「查看留痕 →」链接。
/// 未读时 elevated 卡，已读时 flat + opacity 0.82。
///
/// 用法:
/// ```dart
/// MlsNotificationTile(
///   icon: Icons.handshake,
///   accentColor: MlsColors.primary,
///   title: '李红 发起了带看申请',
///   subtitle: '万达华府 · 3室 · 待你同意',
///   time: '15:06',
///   unread: true,
///   hasTraceLink: true,
///   onTap: () => ...,
/// )
/// ```
class MlsNotificationTile extends StatelessWidget {
  /// 左侧圆形区域图标
  final IconData icon;

  /// 强调色 (图标色 + 圆形底色 12%)
  final Color accentColor;

  /// 标题 (14 / w600 / primary, 单行省略)
  final String title;

  /// 副文 (12 / secondary / line-height 1.5)
  final String subtitle;

  /// 时间 (mono 10 / tertiary)
  final String time;

  /// 是否未读
  final bool unread;

  /// 是否有 "查看留痕 →" 链接
  final bool hasTraceLink;

  /// 点击回调
  final VoidCallback? onTap;

  /// 额外右侧操作
  final Widget? trailing;

  const MlsNotificationTile({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
    this.hasTraceLink = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cardVariant = unread ? MlsCardVariant.elevated : MlsCardVariant.flat;

    final card = MlsCard(
      variant: cardVariant,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Opacity(
        opacity: unread ? 1.0 : 0.82,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 左：40×40 圆形图标 ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: accentColor),
            ),

            const SizedBox(width: 12),

            // ── 中：标题 + 副文 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 标题行 ──
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MlsColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MlsColors.danger,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        time,
                        style: TextStyle(
                          fontFamily: MlsTypography.monoFamily,
                          fontFamilyFallback: MlsTypography.monoFallback,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: MlsColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  // ── 副文 ──
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontFamilyFallback: MlsTypography.sansFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: MlsColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // ── 查看留痕链接 ──
                  if (hasTraceLink)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '查看留痕',
                            style: TextStyle(
                              fontFamilyFallback: MlsTypography.sansFallback,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: MlsColors.primary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.north_east, size: 12, color: MlsColors.primary),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );

    return card;
  }
}
