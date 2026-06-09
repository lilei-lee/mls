import 'package:flutter/material.dart';
import '../../theme/mls_animations.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';
import 'mls_card.dart';

/// 跟进时间线单项 V1
///
/// 左轨（30 圆图标 + 连线）+ 右卡。cur 时呼吸光环。带 trace 链接可点跳留痕。
///
/// 用法:
/// ```dart
/// MlsFollowItem(
///   icon: Icons.phone,
///   title: '电话回访',
///   detail: '客户对万达华府感兴趣...',
///   time: 'TODAY · 14:30',
///   agent: '张三',
///   cur: true,
///   traceId: 'xxx',
///   onTraceTap: () => ...,
///   isLast: false,
/// )
/// ```
class MlsFollowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String time;
  final String? agent;
  final bool cur;
  final bool isLast;
  final String? traceId;
  final VoidCallback? onTraceTap;

  const MlsFollowItem({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
    this.agent,
    this.cur = false,
    this.isLast = false,
    this.traceId,
    this.onTraceTap,
  });

  @override
  Widget build(BuildContext context) {
    final node = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cur ? MlsColors.primaryBg : const Color(0x0D0F172A),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 15, color: cur ? MlsColors.primary : MlsColors.textSecondary),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              cur
                  ? MlsPulse(pulseColor: MlsColors.primary, maxRadius: 22, child: node)
                  : node,
              if (!isLast)
                Container(
                  width: 1.5,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: MlsColors.borderMid,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: MlsCard(
              padding: const EdgeInsets.all(12),
              onTap: traceId != null ? onTraceTap : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: MlsColors.textPrimary,
                          ),
                        ),
                      ),
                      if (traceId != null)
                        Icon(Icons.north_east, size: 14, color: MlsColors.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: MlsTypography.body2,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontFamily: MlsTypography.monoFamily,
                          fontFamilyFallback: MlsTypography.monoFallback,
                          fontSize: 10,
                          color: MlsColors.textTertiary,
                        ),
                      ),
                      if (agent != null) ...[
                        const Spacer(),
                        Text(
                          agent!,
                          style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 10.5,
                            color: MlsColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
