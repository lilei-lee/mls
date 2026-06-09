import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 推入详情页统一顶栏 V1
///
/// sticky 吸顶，返回 + 标题 + 右槽。支持亮/暗两态。
///
/// 用法:
/// ```dart
/// // 房源详情 - 分享+收藏
/// MlsNavBar(
///   title: '房源详情',
///   right: Row(children: [...icons...]),
/// )
///
/// // 通知中心 - 副标题+全部已读
/// MlsNavBar(
///   title: '消息通知',
///   sub: '03 UNREAD',
///   right: GestureDetector(child: Text('全部已读', ...)),
/// )
///
/// // 成交确认 - dark
/// MlsNavBar(
///   title: '成交确认 · 留痕',
///   dark: true,
///   right: _securedBadge(),
/// )
/// ```
///
/// 设计约束:
/// - 高度 52, 左 padding 6, 右 8
/// - 返回区: 40×40, 圆角 lg, chevron_left 24
/// - 标题: 16/w600/-0.2 单行省略
/// - 副标题: mono 9.5/letterSpacing 1.5/大写
/// - dark=true: 白字透明底
/// - dark=false: bgPageStart@86% + 底部 0.5px borderLight
class MlsNavBar extends StatelessWidget {
  /// 主标题
  final String title;

  /// 可选副标题 (mono 大写，如 "03 UNREAD")
  final String? sub;

  /// 右侧槽位 (图标按钮组或文字)
  final Widget? right;

  /// 深色模式 (用于深色 Hero 区)
  final bool dark;

  /// 返回回调 (默认 Navigator.maybePop)
  final VoidCallback? onBack;

  /// 底部 padding (用于在 CustomScrollView 中留出 sliver 空间)
  final bool includeBottomBorder;

  const MlsNavBar({
    super.key,
    required this.title,
    this.sub,
    this.right,
    this.dark = false,
    this.onBack,
    this.includeBottomBorder = true,
  });

  Color get _fg => dark ? Colors.white : MlsColors.textPrimary;
  Color get _subFg =>
      dark ? const Color(0x99FFFFFF) : MlsColors.textTertiary; // rgba(255,255,255,.6)
  Color get _bg => dark
      ? Colors.transparent
      : MlsColors.bgPageStart.withOpacity(0.86);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(
        color: _bg,
        border: !dark && includeBottomBorder
            ? const Border(
                bottom: BorderSide(color: MlsColors.borderLight, width: 0.5),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 返回区 ──
          GestureDetector(
            onTap: onBack ?? () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: MlsRadius.buttonLg,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.chevron_left, size: 24, color: _fg),
            ),
          ),

          const SizedBox(width: 8),

          // ── 标题区 ──
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: _fg,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      sub!,
                      style: TextStyle(
                        fontFamily: MlsTypography.monoFamily,
                        fontFamilyFallback: MlsTypography.monoFallback,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                        color: _subFg,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── 右槽 ──
          if (right != null) right!,
        ],
      ),
    );
  }
}
