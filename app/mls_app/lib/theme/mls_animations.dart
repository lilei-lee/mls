import 'package:flutter/material.dart';

/// MLS 动画系统 V1
///
/// 三类动画:
/// 1. 入场动画 (MlsIn) - 各模块淡入 + 上滑, 错峰
/// 2. 持续动画 (MlsPulse) - 活体信号, 在线点 / 当前节点
/// 3. 进度动画 - 环 / 条, 用 AnimationController 在组件内自管
///
/// 时长参考网页版:
///   入场 550ms / 进度环 1800ms / 进度条 1200ms / pulse 2000ms / scan 3000ms
class MlsAnimations {
  MlsAnimations._();

  // ============ 时长 ============
  static const Duration inDuration = Duration(milliseconds: 550);
  static const Duration ringDuration = Duration(milliseconds: 1800);
  static const Duration barDuration = Duration(milliseconds: 1200);
  static const Duration pulseDuration = Duration(milliseconds: 2000);
  static const Duration scanDuration = Duration(milliseconds: 3000);
  static const Duration tickDuration = Duration(milliseconds: 1000);

  // ============ 缓动曲线 ============

  /// 入场缓动: cubic-bezier(0.22,0.61,0.36,1) ≈ easeOutCubic
  static const Curve inCurve = Curves.easeOutCubic;

  /// 进度条/环缓动: cubic-bezier(0.65,0,0.35,1)
  static const Curve progressCurve = Cubic(0.65, 0, 0.35, 1);

  /// pulse 缓动
  static const Curve pulseCurve = Curves.easeInOut;

  // ============ 错峰 ============

  /// 模块错峰入场延迟 (80ms / 阶)
  /// 用法: MlsIn(delayIndex: 2) → 延迟 160ms 入场
  static Duration stagger(int index) =>
      Duration(milliseconds: 80 * index);
}

/// 入场动画 widget
///
/// 包裹任意 child, 自动播放 mlsIn (淡入 + 从下上滑 14px)
///
/// 用法:
/// ```
/// MlsIn(delayIndex: 0, child: Header(...)),
/// MlsIn(delayIndex: 1, child: HeroCard(...)),
/// MlsIn(delayIndex: 2, child: MetricPanel(...)),
/// ```
class MlsIn extends StatefulWidget {
  /// 被包裹的 child
  final Widget child;

  /// 错峰位次 (0 = 立即, 1 = 80ms, 2 = 160ms...)
  final int delayIndex;

  /// 额外固定延迟(ms), 与 delayIndex 叠加
  final int delayMs;

  /// 是否启用动画(false 时立即显示)
  final bool enabled;

  const MlsIn({
    super.key,
    required this.child,
    this.delayIndex = 0,
    this.delayMs = 0,
    this.enabled = true,
  });

  @override
  State<MlsIn> createState() => _MlsInState();
}

class _MlsInState extends State<MlsIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MlsAnimations.inDuration,
      vsync: this,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: MlsAnimations.inCurve,
    );
    _opacity = curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.16), // ≈ 14px/88px child
      end: Offset.zero,
    ).animate(curve);

    if (widget.enabled) {
      final total = MlsAnimations.stagger(widget.delayIndex) +
          Duration(milliseconds: widget.delayMs);
      Future.delayed(total, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

/// 呼吸 pulse widget
///
/// 用于活体信号: 在线点 / 当前节点 / LIVE 标
/// 视觉: 中心 child 静止, 外圈圆形以颜色色淡入淡出 + 缩放
///
/// 用法:
/// ```
/// MlsPulse(
///   pulseColor: MlsColors.online,
///   child: Container(
///     width: 7, height: 7,
///     decoration: BoxDecoration(
///       shape: BoxShape.circle,
///       color: MlsColors.online,
///     ),
///   ),
/// )
/// ```
class MlsPulse extends StatefulWidget {
  /// 中心静止 child (通常是一个小色圆)
  final Widget child;

  /// pulse 外圈颜色 (默认在线绿)
  final Color pulseColor;

  /// 外圈最大半径增量 (默认中心 child 的 1.5 倍范围)
  final double maxRadius;

  /// 是否启用
  final bool enabled;

  const MlsPulse({
    super.key,
    required this.child,
    this.pulseColor = const Color(0xFF22C55E),
    this.maxRadius = 14,
    this.enabled = true,
  });

  @override
  State<MlsPulse> createState() => _MlsPulseState();
}

class _MlsPulseState extends State<MlsPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MlsAnimations.pulseDuration,
      vsync: this,
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(MlsPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            // 0~1 三角波: 0→0.5→0
            final t = _controller.value;
            final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
            final size = widget.maxRadius * (0.5 + 0.5 * wave);
            final opacity = (1 - wave) * 0.35;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.pulseColor.withOpacity(opacity),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

/// 闪烁文字 widget - 用于倒计时秒数 / LIVE 时钟
///
/// 1s 周期的 opacity 渐变 1 → 0.4 → 1
class MlsTick extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const MlsTick({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<MlsTick> createState() => _MlsTickState();
}

class _MlsTickState extends State<MlsTick>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MlsAnimations.tickDuration,
      vsync: this,
    );
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.4).animate(_controller),
      child: widget.child,
    );
  }
}
