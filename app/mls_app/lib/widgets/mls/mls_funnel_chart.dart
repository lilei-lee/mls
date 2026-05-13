import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 漏斗单层数据
class FunnelStage {
  final String label;
  final int count;

  /// 该层到下一层间隙的文字 (如 "75%"), null 则不显示
  final String? betweenLabel;

  const FunnelStage({
    required this.label,
    required this.count,
    this.betweenLabel,
  });
}

/// MLS 转化漏斗 — 3 层倒梯形
///
/// 用法:
/// ```
/// MlsFunnelChart(
///   stages: [
///     FunnelStage(label: '新增', count: 85, betweenLabel: '75%'),
///     FunnelStage(label: '带看', count: 64, betweenLabel: '33%'),
///     FunnelStage(label: '成交', count: 28),
///   ],
///   headerTrailing: MlsSegmentedControl(...),
/// )
/// ```
class MlsFunnelChart extends StatelessWidget {
  final List<FunnelStage> stages;
  final double height;
  final List<Color> stageColors;
  final bool showLabels;
  final Widget? headerTrailing;

  const MlsFunnelChart({
    super.key,
    required this.stages,
    this.height = 240,
    this.stageColors = const [
      MlsColors.primary,
      MlsColors.primaryLight,
      MlsColors.success,
    ],
    this.showLabels = true,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (headerTrailing != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [headerTrailing!],
          ),
        if (headerTrailing != null) const SizedBox(height: 10),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _FunnelPainter(
              stages: stages,
              stageColors: stageColors,
              showLabels: showLabels,
            ),
          ),
        ),
      ],
    );
  }
}

class _FunnelPainter extends CustomPainter {
  final List<FunnelStage> stages;
  final List<Color> stageColors;
  final bool showLabels;

  _FunnelPainter({
    required this.stages,
    required this.stageColors,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stages.isEmpty) return;

    final n = stages.length;
    const topW = 0.85;
    const bottomW = 0.35;
    const gapH = 8.0;

    final totalGap = gapH * (n - 1);
    final tierH = (size.height - totalGap) / n;
    final centerX = size.width / 2;

    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final topRatio = topW + (bottomW - topW) * t;
      final botRatio = topW + (bottomW - topW) * (t + 1.0 / (n - 1 + 0.001));

      final y = i * (tierH + gapH);
      final topWidth = size.width * topRatio;
      final botWidth = size.width * botRatio;

      // trapezoid path
      final path = Path()
        ..moveTo(centerX - topWidth / 2, y)
        ..lineTo(centerX + topWidth / 2, y)
        ..lineTo(centerX + botWidth / 2, y + tierH)
        ..lineTo(centerX - botWidth / 2, y + tierH)
        ..close();

      final fill = stageColors.length > i
          ? stageColors[i]
          : stageColors.last;
      canvas.drawPath(path, Paint()..color = fill);

      // label
      if (showLabels) {
        final s = stages[i];
        final text = '${s.label} ${s.count}';
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              fontFamilyFallback: ['PingFang SC', 'Microsoft YaHei'],
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(centerX - tp.width / 2, y + tierH / 2 - tp.height / 2),
        );
      }

      // betweenLabel in gap below this tier
      if (i < n - 1 && stages[i].betweenLabel != null) {
        final gy = y + tierH + gapH / 2;
        final bt = stages[i].betweenLabel!;
        final btp = TextPainter(
          text: TextSpan(
            text: bt,
            style: MlsTypography.caption1.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // small dot indicator
        final dotX = centerX;
        canvas.drawCircle(
          Offset(dotX, gy),
          3,
          Paint()..color = Colors.white.withValues(alpha: 0.3),
        );
        // downward arrow hint
        final arrowY = gy + 7;
        canvas.drawLine(
          Offset(dotX, arrowY - 4),
          Offset(dotX, arrowY + 4),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.2)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );

        btp.paint(
          canvas,
          Offset(centerX + 14, gy - btp.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FunnelPainter old) =>
      old.stages != stages || old.stageColors != stageColors;
}
