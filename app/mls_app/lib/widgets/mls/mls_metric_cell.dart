import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// MLS 单格 Metric Cell V1
///
/// 工作仪表盘的核心数据单元。一格 = 一个 metric。
/// 顶部小标签 + 大数字 + (可选) 上下文/趋势 + (可选) 底部视觉化辅助 (sparkline / mini bars / progress bar)
///
/// 用法:
/// ```
/// // 简单形态
/// MlsMetricCell(label: '待办', value: '02', valueColor: MlsColors.danger)
///
/// // 带辅助进度条
/// MlsMetricCell(
///   label: '本月奖金',
///   value: '¥8,400',
///   suffix: '已结算',
///   valueColor: MlsColors.gold,
///   trailing: MlsProgressBar(percent: 0.56, color: MlsColors.gold),
/// )
///
/// // 带 sparkline
/// MlsMetricCell(
///   label: '协作活跃',
///   value: '07',
///   suffix: '↑ 2',
///   trailing: MlsSparkline(points: [3,5,4,6,5,7], color: MlsColors.primary),
/// )
///
/// // 带 mini bars
/// MlsMetricCell(
///   label: '本周带看',
///   value: '04',
///   trailing: MlsMiniBars(values: [2,4,3,5,4,4,1]),
/// )
/// ```
class MlsMetricCell extends StatelessWidget {
  /// 顶部小标签 (灰色, 11px sans)
  final String label;

  /// 大数字 / 主值 (24-32px mono)
  final String value;

  /// 主值旁的小后缀 (如 "/5" "↑2" "已结算"), 通常灰色
  final String? suffix;

  /// 主值的颜色 (默认 textPrimary)
  final Color valueColor;

  /// 主值字号 (默认 26)
  final double valueFontSize;

  /// 底部辅助视觉 widget (sparkline / mini bars / progress bar / null)
  /// 推荐高度 24-32
  final Widget? trailing;

  /// 整体内边距 (默认 14)
  final EdgeInsetsGeometry padding;

  const MlsMetricCell({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.valueColor = MlsColors.textPrimary,
    this.valueFontSize = 26,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标签
          Text(
            label,
            style: const TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 11,
              color: MlsColors.textTertiary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          // 数字 + suffix
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: MlsTypography.monoFamily,
                  fontFamilyFallback: MlsTypography.monoFallback,
                  fontSize: valueFontSize,
                  fontWeight: MlsTypography.semibold,
                  color: valueColor,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    suffix!,
                    style: const TextStyle(
                      fontFamily: MlsTypography.monoFamily,
                      fontFamilyFallback: MlsTypography.monoFallback,
                      fontSize: 11,
                      color: MlsColors.textTertiary,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // 底部辅助视觉
          if (trailing != null) ...[
            const SizedBox(height: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 配套小组件 1: 进度条 (横向, 圆角)
// ============================================================

/// 横向进度条 V1
///
/// 用法:
/// ```
/// MlsProgressBar(percent: 0.56, color: MlsColors.gold)
/// ```
class MlsProgressBar extends StatelessWidget {
  /// 进度 0.0 - 1.0
  final double percent;

  /// 进度色 (默认 primary)
  final Color color;

  /// 底色 (默认 color.withOpacity(0.12))
  final Color? trackColor;

  /// 高度 (默认 4)
  final double height;

  const MlsProgressBar({
    super.key,
    required this.percent,
    this.color = MlsColors.primary,
    this.trackColor,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (_, constraints) {
        return Stack(
          children: [
            // 底
            Container(
              height: height,
              decoration: BoxDecoration(
                color: trackColor ?? color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // 进度
            FractionallySizedBox(
              widthFactor: p,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// 配套小组件 2: 迷你柱状图 (7 天活跃用)
// ============================================================

/// 迷你柱状图 V1
///
/// 用法:
/// ```
/// MlsMiniBars(values: [2, 4, 3, 5, 4, 4, 1])              // 默认蓝色, 最高亮
/// MlsMiniBars(values: [...], color: MlsColors.gold)       // 自定义色
/// MlsMiniBars(values: [...], highlightLastIndex: true)    // 最后一根高亮
/// ```
class MlsMiniBars extends StatelessWidget {
  /// 数据点 (任意数值, 内部归一化)
  final List<double> values;

  /// 柱色 (默认 primary)
  final Color color;

  /// 柱间距 (默认 3)
  final double gap;

  /// 高度 (默认 24)
  final double height;

  /// 圆角 (默认 1.5)
  final double radius;

  /// 高亮最后一根 (默认 true, 强调"今天")
  final bool highlightLast;

  /// 非高亮柱透明度 (默认 0.35)
  final double dimOpacity;

  const MlsMiniBars({
    super.key,
    required this.values,
    this.color = MlsColors.primary,
    this.gap = 3,
    this.height = 24,
    this.radius = 1.5,
    this.highlightLast = true,
    this.dimOpacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    final max = values.reduce((a, b) => a > b ? a : b);
    final safeMax = max == 0 ? 1.0 : max;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: FractionallySizedBox(
                heightFactor:
                    (values[i] / safeMax).clamp(0.1, 1.0).toDouble(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlightLast && i == values.length - 1
                        ? color
                        : color.withOpacity(dimOpacity),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 配套小组件 3: Sparkline (折线趋势图)
// ============================================================

/// Sparkline 折线趋势 V1
///
/// 用法:
/// ```
/// MlsSparkline(points: [3, 5, 4, 6, 5, 7])                   // 默认 primary
/// MlsSparkline(points: [...], color: MlsColors.gold)         // 金色趋势
/// MlsSparkline(points: [...], fillBelow: true)               // 折线下方半透明填充
/// ```
class MlsSparkline extends StatelessWidget {
  /// 数据点
  final List<double> points;

  /// 线色 (默认 primary)
  final Color color;

  /// 线宽 (默认 1.6)
  final double strokeWidth;

  /// 是否填充折线下方 (默认 true)
  final bool fillBelow;

  /// 高度 (默认 24)
  final double height;

  const MlsSparkline({
    super.key,
    required this.points,
    this.color = MlsColors.primary,
    this.strokeWidth = 1.6,
    this.fillBelow = true,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: points,
          color: color,
          strokeWidth: strokeWidth,
          fillBelow: fillBelow,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double strokeWidth;
  final bool fillBelow;

  _SparklinePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.fillBelow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final minVal = points.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 1e-6 ? 1.0 : maxVal - minVal;

    final dx = size.width / (points.length - 1);
    // 留 strokeWidth 顶底 padding 防止线被裁切
    final pad = strokeWidth + 1;
    final h = size.height - pad * 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final norm = (points[i] - minVal) / range;
      final y = pad + h * (1 - norm);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fillBelow) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // 末端点
    final lastX = dx * (points.length - 1);
    final lastNorm = (points.last - minVal) / range;
    final lastY = pad + h * (1 - lastNorm);
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(lastX, lastY), strokeWidth + 0.5, dotPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.fillBelow != fillBelow;
}
