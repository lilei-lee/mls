import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_shadows.dart';
import '../../theme/mls_typography.dart';
import 'mls_avatar.dart';
import 'mls_countdown_clock.dart';
import 'mls_primary_button.dart';

/// MLS Hero Today 大卡片 V1
///
/// 工作台顶部"今日带看"焦点卡, 蓝色 hero 渐变背景。
/// 视觉钩子: 倒计时秒数闪烁 + CTA 立即准备 + 协作头像 stack
///
/// 用法:
/// ```
/// MlsHeroToday(
///   topLabel: 'TODAY · 15:00',
///   subtitle: '今日带看 · 与李红协同',
///   countdownTarget: DateTime.now().add(Duration(hours: 3, minutes: 28)),
///   title: '万达华府 · 3室朝南',
///   description: '108㎡ · 客户王先生 · 已二次咨询',
///   collaborators: ['李红', '王先生'],
///   ctaText: '立即准备',
///   onCtaPressed: () => ...,
/// )
/// ```
class MlsHeroToday extends StatelessWidget {
  /// 左上 mono 大写标签 (如 "TODAY · 15:00")
  final String topLabel;

  /// 副标题 (在 topLabel 下方, 中文 sans 浅色)
  final String subtitle;

  /// 倒计时目标时间 (传 null 不显示倒计时区)
  final DateTime? countdownTarget;

  /// 倒计时上方的标签文字 (默认 "还有")
  final String countdownLabel;

  /// 主标题 (中文 sans, 大字)
  final String title;

  /// 详细描述
  final String description;

  /// 协作头像姓名列表 (会渲染成 stack, 头像带蓝色边框)
  final List<String> collaborators;

  /// CTA 按钮文字
  final String ctaText;

  /// CTA 按钮 trailing icon (默认 arrow_forward)
  final IconData? ctaIcon;

  /// CTA 点击回调
  final VoidCallback? onCtaPressed;

  /// 卡片整体点击 (与 CTA 不同的位置, 比如点空白区进详情)
  final VoidCallback? onCardTap;

  const MlsHeroToday({
    super.key,
    required this.topLabel,
    required this.subtitle,
    this.countdownTarget,
    this.countdownLabel = '还有',
    required this.title,
    required this.description,
    this.collaborators = const [],
    this.ctaText = '立即准备',
    this.ctaIcon,
    this.onCtaPressed,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        gradient: MlsColors.heroBlue,
        borderRadius: MlsRadius.hero,
        boxShadow: MlsShadows.heroBlue,
      ),
      child: ClipRRect(
        borderRadius: MlsRadius.hero,
        child: Stack(
          children: [
            // 右上角放射状高光 (装饰)
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            // 主内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部行: 标签 + 倒计时
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topLabel,
                              style: MlsTypography.monoLabel.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontFamilyFallback: MlsTypography.sansFallback,
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (countdownTarget != null) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              countdownLabel,
                              style: TextStyle(
                                fontFamily: MlsTypography.monoFamily,
                                fontFamilyFallback: MlsTypography.monoFallback,
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.6),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            MlsCountdownClock(
                              target: countdownTarget!,
                              textStyle:
                                  MlsTypography.countdown.copyWith(
                                color: Colors.white,
                              ),
                              secondsStyle:
                                  MlsTypography.countdown.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 11),
                  // 分割线
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(height: 11),
                  // 主标题
                  Text(
                    title,
                    style: TextStyle(
                      fontFamilyFallback: MlsTypography.sansFallback,
                      fontSize: 16,
                      fontWeight: MlsTypography.semibold,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamilyFallback: MlsTypography.sansFallback,
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 底部行: 协作头像 + CTA
                  Row(
                    children: [
                      _buildCollaboratorStack(),
                      const Spacer(),
                      if (onCtaPressed != null)
                        MlsPrimaryButton(
                          text: ctaText,
                          variant: MlsButtonVariant.outline,
                          size: MlsButtonSize.small,
                          trailingIcon:
                              ctaIcon ?? Icons.arrow_forward,
                          onPressed: onCtaPressed,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onCardTap == null) return card;
    return GestureDetector(
      onTap: onCardTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  /// 协作伙伴头像 stack (头像描蓝边以融入 hero 卡片)
  Widget _buildCollaboratorStack() {
    if (collaborators.isEmpty) return const SizedBox.shrink();
    return MlsAvatarStack(
      names: collaborators,
      avatarSize: 26,
      overlap: -8,
      borderWidth: 2,
      borderColor: MlsColors.primary,
    );
  }
}
