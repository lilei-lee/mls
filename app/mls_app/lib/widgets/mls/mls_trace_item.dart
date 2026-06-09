import 'package:flutter/material.dart';
import '../../theme/mls_animations.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';
import 'mls_avatar.dart';
import 'mls_card.dart';

/// 留痕侧 (双方独立留痕、互不可改)
enum TraceSide {
  /// 买方经纪人 (蓝色)
  ba,

  /// 卖方经纪人 (金色)
  la,

  /// 签字 (灰色)
  sign,
}

/// 留痕时间线单项 V1
///
/// 左轨 (30宽) + 右卡 (Expanded)。
/// - 节点圆 30×30: ba 底 primary@14%、la 底 gold@14%、future 虚线描边
/// - current 时呼吸光环 (MlsPulse)
/// - 连接线: done 实线同侧色@35%, 未完成虚线
/// - 右卡用 MlsCard: future→flat+虚线, current→elevated, 其余→primary
///
/// 用法:
/// ```dart
/// MlsTraceItem(
///   side: TraceSide.ba,
///   icon: Icons.send,
///   title: '发起带看申请',
///   detail: '申请带客户王先生看「万达华府 · 3室」',
///   time: 'TODAY · 09:12:04',
///   hash: '0x7f3a…91c',
///   done: true,
///   current: false,
///   future: false,
///   isLast: false,
/// )
/// ```
class MlsTraceItem extends StatelessWidget {
  /// 留痕侧 (BA / LA / SIGN)
  final TraceSide side;

  /// 节点圆内图标
  final IconData icon;

  /// 标题 (13.5 / w600 / primary)
  final String title;

  /// 描述 (12 / secondary)
  final String detail;

  /// 时间 (mono 10 / tertiary)
  final String time;

  /// 可选 mono 哈希 (显示 lock + hash)
  final String? hash;

  /// 谁留的痕 (用于 Avatar)
  final String? who;

  /// 已完成 (实线连接)
  final bool done;

  /// 当前项 (呼吸光环 + elevated 卡)
  final bool current;

  /// 未来项 (虚线圆 + flat 卡)
  final bool future;

  /// 是否最后一项 (无连接线)
  final bool isLast;

  const MlsTraceItem({
    super.key,
    required this.side,
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
    this.hash,
    this.who,
    this.done = true,
    this.current = false,
    this.future = false,
    this.isLast = false,
  });

  Color get _sideColor {
    switch (side) {
      case TraceSide.ba:
        return MlsColors.primary;
      case TraceSide.la:
        return MlsColors.gold;
      case TraceSide.sign:
        return MlsColors.textTertiary;
    }
  }

  String get _sideLabel {
    switch (side) {
      case TraceSide.ba:
        return 'BA 留痕';
      case TraceSide.la:
        return 'LA 留痕';
      case TraceSide.sign:
        return 'PENDING';
    }
  }

  Color get _sideBg => _sideColor.withOpacity(0.14);
  Color get _sideTagBg => _sideColor.withOpacity(0.10);

  @override
  Widget build(BuildContext context) {
    final nodeContent = Icon(icon, size: 15, color: future ? MlsColors.textTertiary : _sideColor);

    // 节点装饰
    final node = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: future ? Colors.transparent : _sideBg,
        border: future
            ? Border.all(color: MlsColors.borderStrong, width: 1.5, strokeAlign: BorderSide.strokeAlignInside)
            : null,
      ),
      alignment: Alignment.center,
      child: nodeContent,
    );

    final nodeWithPulse = current
        ? MlsPulse(
            pulseColor: _sideColor,
            maxRadius: 22,
            enabled: true,
            child: node,
          )
        : node;

    // 连接线
    Widget? connector;
    if (!isLast) {
      connector = Container(
        width: 1.5,
        height: 28,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: done
            ? BoxDecoration(color: _sideColor.withOpacity(0.35))
            : null,
        child: done
            ? null
            : CustomPaint(
                size: const Size(1.5, 28),
                painter: _DashPainter(color: MlsColors.borderStrong, dashLength: 7, gapLength: 5),
              ),
      );
    }

    // 卡片 variant
    final cardVariant = future
        ? MlsCardVariant.flat
        : current
            ? MlsCardVariant.elevated
            : MlsCardVariant.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 左轨 ──
        SizedBox(
          width: 30,
          child: Column(
            children: [
              nodeWithPulse,
              if (connector != null) connector,
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ── 右卡 ──
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: future
                ? Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: MlsRadius.cardLg,
                      border: Border.all(color: MlsColors.borderStrong, width: 0.5),
                      // dashed border simulated by solid — Flutter limitation
                    ),
                    child: _buildCardContent(),
                  )
                : MlsCard(
                    variant: cardVariant,
                    padding: const EdgeInsets.all(13),
                    child: _buildCardContent(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 标题行 ──
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _sideTagBg,
                borderRadius: BorderRadius.circular(MlsRadius.xs),
              ),
              child: Text(
                _sideLabel,
                style: TextStyle(
                  fontFamily: MlsTypography.monoFamily,
                  fontFamilyFallback: MlsTypography.monoFallback,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: _sideColor,
                ),
              ),
            ),
          ],
        ),

        // ── 描述 ──
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            detail,
            style: TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: MlsColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),

        // ── 元信息行 ──
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(
            children: [
              if (side != TraceSide.sign && who != null) ...[
                MlsAvatar(name: who!, size: 16),
                const SizedBox(width: 4),
              ],
              Text(
                time,
                style: TextStyle(
                  fontFamily: MlsTypography.monoFamily,
                  fontFamilyFallback: MlsTypography.monoFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: MlsColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
              if (hash != null) ...[
                const Spacer(),
                Icon(Icons.lock, size: 10, color: MlsColors.textTertiary),
                const SizedBox(width: 3),
                Text(
                  hash!,
                  style: TextStyle(
                    fontFamily: MlsTypography.monoFamily,
                    fontFamilyFallback: MlsTypography.monoFallback,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                    color: MlsColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 竖线虚线 painter (7px 段 + 5px 间隔)
class _DashPainter extends CustomPainter {
  final Color color;
  final double dashLength;
  final double gapLength;

  _DashPainter({
    required this.color,
    this.dashLength = 7,
    this.gapLength = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    var y = 0.0;
    while (y < size.height) {
      final next = (y + dashLength).clamp(0.0, size.height);
      canvas.drawLine(Offset(0, y), Offset(0, next), paint);
      y = next + gapLength;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.dashLength != dashLength || old.gapLength != gapLength;
}
