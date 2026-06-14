import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/mls_typography.dart';

/// 甜甜圈单段数据
class DonutSegment {
  final String label;
  final double value;
  final Color color;

  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// MLS 甜甜圈 — 多段环形 + 中心数字 + legend
///
/// 用法:
/// ```
/// MlsDonutChart(
///   segments: [
///     DonutSegment(label: '在售', value: 12, color: MlsColors.primaryLight),
///     ...
///   ],
///   legendDirection: Axis.horizontal,
/// )
/// ```
class MlsDonutChart extends StatefulWidget {
  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final Widget? center;
  final Axis legendDirection;
  final bool showLegend;
  final bool animate;
  final double startAngle;

  const MlsDonutChart({
    super.key,
    required this.segments,
    this.size = 180,
    this.strokeWidth = 28,
    this.center,
    this.legendDirection = Axis.vertical,
    this.showLegend = true,
    this.animate = true,
    this.startAngle = -math.pi / 2,
  });

  @override
  State<MlsDonutChart> createState() => _MlsDonutChartState();
}

class _MlsDonutChartState extends State<MlsDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _sweep = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total =
        widget.segments.fold<double>(0, (s, seg) => s + seg.value);

    final defaultCenter = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TOTAL',
            style: MlsTypography.monoLabel.copyWith(color: Colors.white54)),
        const SizedBox(height: 2),
        Text('${total.round()}',
            style: MlsTypography.monoLarge.copyWith(color: Colors.white)),
        const SizedBox(height: 2),
        Text('累计',
            style: MlsTypography.monoTinyLabel
                .copyWith(color: Colors.white38)),
      ],
    );

    return AnimatedBuilder(
      animation: _sweep,
      builder: (_, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _DonutPainter(
                      segments: widget.segments,
                      strokeWidth: widget.strokeWidth,
                      startAngle: widget.startAngle,
                      sweepFraction: _sweep.value,
                    ),
                  ),
                  widget.center ?? defaultCenter,
                ],
              ),
            ),
            if (widget.showLegend) const SizedBox(height: 12),
            if (widget.showLegend) _buildLegend(),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    final children = widget.segments.map((seg) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: seg.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text('${seg.label} ${seg.value.round()}',
                style: MlsTypography.caption1
                    .copyWith(color: Colors.white70)),
          ],
        ),
      );
    }).toList();

    if (widget.legendDirection == Axis.horizontal) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: children,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;
  final double startAngle;
  final double sweepFraction;

  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final total = segments.fold<double>(0, (s, seg) => s + seg.value);
    if (total <= 0) return;

    final ringRect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    var angle = startAngle;
    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * math.pi * sweepFraction;
      if (sweep > 0.001) {
        final paint = Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(ringRect, angle, sweep, false, paint);
      }
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments ||
      old.strokeWidth != strokeWidth ||
      old.sweepFraction != sweepFraction;
}
