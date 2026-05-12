import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/mls_animations.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// MLS 倒计时数字 V1
///
/// 显示 HH:MM:SS, 内部 Timer.periodic 每秒刷新, 秒数部分 mls-tick 闪烁强化活体感。
/// 时间到 (target <= now) 后停止 Timer, 显示 "00:00:00" + onExpired 回调。
///
/// 用法:
/// ```
/// MlsCountdownClock(target: DateTime.now().add(Duration(hours: 3, minutes: 28)))
/// MlsCountdownClock(target: ..., compact: true)   // 短形态 "3:28"
/// ```
class MlsCountdownClock extends StatefulWidget {
  /// 倒计时目标时刻
  final DateTime target;

  /// 主样式 (默认 countdown 24px mono)
  final TextStyle? textStyle;

  /// 秒数样式 (默认与 textStyle 一致, 但加 mls-tick 闪烁)
  final TextStyle? secondsStyle;

  /// 是否启用秒数闪烁 (默认 true)
  final bool blinkSeconds;

  /// 短形态: 仅显示 "HH:MM" 不显示秒 (默认 false)
  final bool compact;

  /// 到时回调
  final VoidCallback? onExpired;

  const MlsCountdownClock({
    super.key,
    required this.target,
    this.textStyle,
    this.secondsStyle,
    this.blinkSeconds = true,
    this.compact = false,
    this.onExpired,
  });

  @override
  State<MlsCountdownClock> createState() => _MlsCountdownClockState();
}

class _MlsCountdownClockState extends State<MlsCountdownClock> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final diff = widget.target.difference(DateTime.now());
    if (diff.isNegative || diff == Duration.zero) {
      if (!_expired) {
        _expired = true;
        widget.onExpired?.call();
      }
      if (mounted) setState(() => _remaining = Duration.zero);
      _timer?.cancel();
    } else {
      if (mounted) setState(() => _remaining = diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    final mainStyle = widget.textStyle ?? MlsTypography.countdown;
    final secStyle = widget.secondsStyle ??
        mainStyle.copyWith(
          color: (mainStyle.color ?? MlsColors.textPrimary).withOpacity(0.7),
        );

    if (widget.compact) {
      return Text('${_two(h)}:${_two(m)}', style: mainStyle);
    }

    final secondsText = ':${_two(s)}';
    final secondsWidget = Text(secondsText, style: secStyle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('${_two(h)}:${_two(m)}', style: mainStyle),
        widget.blinkSeconds
            ? MlsTick(child: secondsWidget)
            : secondsWidget,
      ],
    );
  }
}
