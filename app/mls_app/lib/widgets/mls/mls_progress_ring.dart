import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/mls_animations.dart';
import '../../theme/mls_colors.dart';

/// MLS 环形进度 V1
///
/// 圆环 + 入场动画 (stroke-dashoffset 从 0 → percent), 中心可放任意 widget。
///
/// 用法:
/// ```
/// MlsProgressRing(
///   percent: 0.56,
///   size: 84,
///   strokeWidth: 8,
///   valueColor: MlsColors.gold,
///   trackColor: MlsColors.gold.withOpacity(0.12),
///   center: Column(...),  // 56% / 已达成
/// )
/// ```
class MlsProgressRing extends StatefulWidget {
  /// 进度值, 0.0 - 1.0
  final double percent;

  /// 直径
  final double size;

  /// 线宽 (默认 8)
  final double strokeWidth;

  /// 进度条颜色 (默认 primary)
  final Color valueColor;

  /// 底色环颜色 (默认 valueColor.withOpacity(0.12))
  final Color? trackColor;

  /// 中心 widget (一般是百分比 + 副标)
  final Widget? center;

  /// 是否启用入场动画 (默认 true)
  final bool animate;

  /// 动画时长 (默认 1800ms)
  final Duration? duration;

  /// 线尾是否圆头 (默认 true)
  final bool roundedCap;

  /// 起始角度 (rad, 默认 -π/2, 即从 12 点开始)
  final double startAngle;

  const MlsProgressRing({
    super.key,
    required this.percent,
    this.size = 84,
    this.strokeWidth = 8,
    this.valueColor = MlsColors.primary,
    this.trackColor,
    this.center,
    this.animate = true,
    this.duration,
    this.roundedCap = true,
    this.startAngle = -math.pi / 2,
  });

  @override
  State<MlsProgressRing> createState() => _MlsProgressRingState();
}

class _MlsProgressRingState extends State<MlsProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? MlsAnimations.ringDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.percent.clamp(0, 1))
        .animate(CurvedAnimation(
            parent: _controller, curve: MlsAnimations.progressCurve));
    if (widget.animate) {
      // 延迟一点开始, 配合外层 mlsIn 节奏
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MlsProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percent.clamp(0, 1),
      ).animate(CurvedAnimation(
          parent: _controller, curve: MlsAnimations.progressCurve));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.trackColor ?? widget.valueColor.withOpacity(0.12);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(
                percent: _animation.value,
                strokeWidth: widget.strokeWidth,
                valueColor: widget.valueColor,
                trackColor: track,
                roundedCap: widget.roundedCap,
                startAngle: widget.startAngle,
              ),
            ),
          ),
          if (widget.center != null) widget.center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double strokeWidth;
  final Color valueColor;
  final Color trackColor;
  final bool roundedCap;
  final double startAngle;

  _RingPainter({
    required this.percent,
    required this.strokeWidth,
    required this.valueColor,
    required this.trackColor,
    required this.roundedCap,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 底环
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 进度弧
    if (percent <= 0) return;
    final valuePaint = Paint()
      ..color = valueColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = roundedCap ? StrokeCap.round : StrokeCap.butt;

    final sweep = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent ||
      old.valueColor != valueColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
