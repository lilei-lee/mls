import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';
import 'mls_dual_bar_chart.dart'; // DualBarData

/// MLS 双折线图 — 12 月双线 + 数据点 + 气泡
///
/// 用法:
/// ```
/// MlsDualLineChart(
///   data: [DualBarData(month: '1月', laValue: 18, baValue: 10), ...],
///   line1Label: '带看',
///   line2Label: '新增客户',
///   highlightHighLow: true,
/// )
/// ```
class MlsDualLineChart extends StatefulWidget {
  final List<DualBarData> data;
  final double height;
  final Color line1Color;
  final Color line2Color;
  final String? line1Label;
  final String? line2Label;
  final bool showPoints;
  final bool showLegend;
  final bool highlightHighLow;
  final bool animate;

  const MlsDualLineChart({
    super.key,
    required this.data,
    this.height = 220,
    this.line1Color = MlsColors.chartPurple,
    this.line2Color = MlsColors.chartOrange,
    this.line1Label,
    this.line2Label,
    this.showPoints = true,
    this.showLegend = true,
    this.highlightHighLow = false,
    this.animate = true,
  });

  @override
  State<MlsDualLineChart> createState() => _MlsDualLineChartState();
}

class _MlsDualLineChartState extends State<MlsDualLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MlsDualLineChart old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _ctrl.reset();
      if (widget.animate) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _ctrl.forward();
        });
      } else {
        _ctrl.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showLegend &&
                (widget.line1Label != null || widget.line2Label != null))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.line1Label != null) ...[
                      _legendDot(widget.line1Color),
                      const SizedBox(width: 4),
                      Text(widget.line1Label!,
                          style: MlsTypography.caption1
                              .copyWith(color: Colors.white70)),
                    ],
                    if (widget.line1Label != null &&
                        widget.line2Label != null)
                      const SizedBox(width: 16),
                    if (widget.line2Label != null) ...[
                      _legendDot(widget.line2Color),
                      const SizedBox(width: 4),
                      Text(widget.line2Label!,
                          style: MlsTypography.caption1
                              .copyWith(color: Colors.white70)),
                    ],
                  ],
                ),
              ),
            SizedBox(
              height: widget.height,
              child: CustomPaint(
                size: Size.infinite,
                painter: _DualLinePainter(
                  data: widget.data,
                  line1Color: widget.line1Color,
                  line2Color: widget.line2Color,
                  showPoints: widget.showPoints,
                  highlightHighLow: widget.highlightHighLow,
                  progress: _progress.value,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legendDot(Color color) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _DualLinePainter extends CustomPainter {
  final List<DualBarData> data;
  final Color line1Color;
  final Color line2Color;
  final bool showPoints;
  final bool highlightHighLow;
  final double progress;

  _DualLinePainter({
    required this.data,
    required this.line1Color,
    required this.line2Color,
    required this.showPoints,
    required this.highlightHighLow,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final v1 = data.map((d) => d.laValue).toList();
    final v2 = data.map((d) => d.baValue).toList();
    final allVals = [...v1, ...v2];
    final maxVal = allVals.reduce((a, b) => a > b ? a : b);
    final niceMax = _niceCeil(maxVal);

    const leftMargin = 38.0;
    const rightMargin = 8.0;
    const topMargin = 20.0;
    const bottomMargin = 24.0;
    final cw = size.width - leftMargin - rightMargin;
    final ch = size.height - topMargin - bottomMargin;
    if (cw <= 0 || ch <= 0) return;

    // grid lines
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = topMargin + ch * (1 - i / 4);
      canvas.drawLine(
          Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);
      final val = (niceMax * i / 4).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$val',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: ['monospace'],
            fontSize: 9,
            color: Colors.white38,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftMargin - 4);
      tp.paint(canvas, Offset(leftMargin - tp.width - 4, y - tp.height / 2));
    }

    final offsets1 = <Offset>[];
    final offsets2 = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final cx = leftMargin + (cw / (data.length - 1)) * i;
      final y1 = topMargin + ch - (v1[i] / niceMax) * ch;
      final y2 = topMargin + ch - (v2[i] / niceMax) * ch;
      offsets1.add(Offset(cx, y1));
      offsets2.add(Offset(cx, y2));
      // month label
      final mtp = TextPainter(
        text: TextSpan(
          text: data[i].month,
          style: MlsTypography.monoTinyLabel.copyWith(color: Colors.white38),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mtp.paint(canvas,
          Offset(cx - mtp.width / 2, size.height - bottomMargin + 6));
    }

    // draw lines
    _drawLine(canvas, offsets1, line1Color);
    _drawLine(canvas, offsets2, line2Color);

    // data points
    if (showPoints) {
      for (final o in offsets1) {
        _drawPoint(canvas, o, line1Color);
      }
      for (final o in offsets2) {
        _drawPoint(canvas, o, line2Color);
      }
    }

    // highlight labels
    if (highlightHighLow) {
      _drawHighLowLabels(canvas, data, offsets1, v1, line1Color);
      _drawHighLowLabels(canvas, data, offsets2, v2, line2Color);
    }
  }

  void _drawLine(Canvas canvas, List<Offset> pts, Color color) {
    if (pts.length < 2) return;
    final endIdx =
        ((pts.length - 1) * progress).ceil().clamp(0, pts.length - 1);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (endIdx == 0) {
      canvas.drawCircle(pts[0], 2, Paint()..color = color);
      return;
    }

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i <= endIdx; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, linePaint);
  }

  void _drawPoint(Canvas canvas, Offset o, Color color) {
    canvas.drawCircle(
        o, 3.5, Paint()..color = color);
    canvas.drawCircle(
        o,
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _drawHighLowLabels(Canvas canvas, List<DualBarData> data,
      List<Offset> offsets, List<double> values, Color color) {
    if (data.isEmpty) return;
    int hi = 0, lo = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[hi]) hi = i;
      if (values[i] < values[lo]) lo = i;
    }
    _drawOneLabel(canvas, offsets[hi], values[hi], color, true);
    if (lo != hi) _drawOneLabel(canvas, offsets[lo], values[lo], color, false);
  }

  void _drawOneLabel(
      Canvas canvas, Offset o, double val, Color color, bool isHigh) {
    final text = '${val.round()}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: ['monospace'],
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ly = isHigh ? o.dy - tp.height - 2 : o.dy + 4;
    tp.paint(canvas, Offset(o.dx - tp.width / 2, ly));
  }

  double _niceCeil(double v) {
    if (v <= 0) return 10;
    var mag = 1.0;
    while (mag * 10 <= v) mag *= 10;
    final norm = v / mag;
    if (norm <= 1) return mag;
    if (norm <= 2) return 2 * mag;
    if (norm <= 5) return 5 * mag;
    return 10 * mag;
  }

  @override
  bool shouldRepaint(_DualLinePainter old) =>
      old.data != data ||
      old.line1Color != line1Color ||
      old.line2Color != line2Color ||
      old.progress != progress ||
      old.showPoints != showPoints ||
      old.highlightHighLow != highlightHighLow;
}
