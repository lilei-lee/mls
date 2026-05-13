import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 双柱图单月数据点
class DualBarData {
  final String month;
  final double laValue;
  final double baValue;

  const DualBarData({
    required this.month,
    required this.laValue,
    required this.baValue,
  });
}

/// MLS 双柱图 — 12 月 LA/BA 并排柱
///
/// 用法:
/// ```
/// MlsDualBarChart(
///   data: [DualBarData(month: '1月', laValue: 18, baValue: 10), ...],
///   highlightHighLow: true,
/// )
/// ```
class MlsDualBarChart extends StatelessWidget {
  final List<DualBarData> data;
  final double height;
  final Color laColor;
  final Color baColor;
  final bool showLegend;
  final bool highlightHighLow;
  final ValueChanged<int>? onBarTap;

  const MlsDualBarChart({
    super.key,
    required this.data,
    this.height = 200,
    this.laColor = MlsColors.success,
    this.baColor = MlsColors.primaryLight,
    this.showLegend = true,
    this.highlightHighLow = false,
    this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLegend)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(laColor),
                const SizedBox(width: 4),
                Text('LA 房源',
                    style: MlsTypography.caption1
                        .copyWith(color: Colors.white70)),
                const SizedBox(width: 16),
                _legendDot(baColor),
                const SizedBox(width: 4),
                Text('BA 带看',
                    style: MlsTypography.caption1
                        .copyWith(color: Colors.white70)),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DualBarPainter(
              data: data,
              laColor: laColor,
              baColor: baColor,
              highlightHighLow: highlightHighLow,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _DualBarPainter extends CustomPainter {
  final List<DualBarData> data;
  final Color laColor;
  final Color baColor;
  final bool highlightHighLow;

  _DualBarPainter({
    required this.data,
    required this.laColor,
    required this.baColor,
    required this.highlightHighLow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final laValues = data.map((d) => d.laValue).toList();
    final baValues = data.map((d) => d.baValue).toList();
    final allValues = [...laValues, ...baValues];
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);

    // nice ceiling
    final niceMax = _niceCeil(maxVal);

    const leftMargin = 38.0;
    const rightMargin = 8.0;
    const topMargin = 18.0;
    const bottomMargin = 24.0;
    final chartW = size.width - leftMargin - rightMargin;
    final chartH = size.height - topMargin - bottomMargin;
    if (chartW <= 0 || chartH <= 0) return;

    final groupW = chartW / data.length;
    final barW = groupW * 0.33; // each bar ~33% of group width

    // grid lines (4 horizontal)
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    final gridSteps = 4;
    for (var i = 0; i <= gridSteps; i++) {
      final y = topMargin + chartH * (1 - i / gridSteps);
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      // Y-axis label
      final val = (niceMax * i / gridSteps).round();
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

    // find high/low indices for LA
    int laHighIdx = 0, laLowIdx = 0;
    if (highlightHighLow) {
      for (var i = 1; i < data.length; i++) {
        if (data[i].laValue > data[laHighIdx].laValue) laHighIdx = i;
        if (data[i].laValue < data[laLowIdx].laValue) laLowIdx = i;
      }
    }

    // draw bars
    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final groupLeft = leftMargin + groupW * i;
      final groupCenter = groupLeft + groupW / 2;

      // LA bar (left)
      final laH = (d.laValue / niceMax) * chartH;
      final laRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(groupCenter - barW - 2, topMargin + chartH - laH, barW, laH),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(laRect, Paint()..color = laColor);

      // BA bar (right)
      final baH = (d.baValue / niceMax) * chartH;
      final baRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(groupCenter + 2, topMargin + chartH - baH, barW, baH),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(baRect, Paint()..color = baColor);

      // month label
      final mTp = TextPainter(
        text: TextSpan(
          text: d.month,
          style: MlsTypography.monoTinyLabel.copyWith(color: Colors.white38),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupW);
      mTp.paint(
        canvas,
        Offset(groupCenter - mTp.width / 2, size.height - bottomMargin + 6),
      );
    }

    // highlight labels
    if (highlightHighLow) {
      _drawHighlightLabel(canvas, data[laHighIdx], laHighIdx, niceMax, laColor,
          leftMargin, topMargin, chartW, chartH, groupW, data.length);
      if (laLowIdx != laHighIdx) {
        _drawHighlightLabel(canvas, data[laLowIdx], laLowIdx, niceMax, laColor,
            leftMargin, topMargin, chartW, chartH, groupW, data.length);
      }
    }
  }

  void _drawHighlightLabel(Canvas canvas, DualBarData d, int idx, double maxVal,
      Color color, double left, double top, double cw, double ch,
      double gw, int len) {
    final groupCenter = left + gw * idx + gw / 2;
    final barH = (d.laValue / maxVal) * ch;
    final text = '${d.laValue.round()}';
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

    final lx = groupCenter - tp.width / 2;
    final ly = top + ch - barH - tp.height - 4;
    tp.paint(canvas, Offset(lx, ly));
  }

  double _niceCeil(double v) {
    if (v <= 0) return 10;
    final mag = _pow10((v.abs()).toStringAsFixed(0).length - 1);
    final norm = v / mag;
    if (norm <= 1) return mag;
    if (norm <= 2) return 2 * mag;
    if (norm <= 5) return 5 * mag;
    return 10 * mag;
  }

  double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) r *= 10;
    return r;
  }

  @override
  bool shouldRepaint(_DualBarPainter old) =>
      old.data != data ||
      old.laColor != laColor ||
      old.baColor != baColor ||
      old.highlightHighLow != highlightHighLow;
}
