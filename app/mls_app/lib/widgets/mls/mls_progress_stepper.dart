import 'package:flutter/material.dart';
import '../../theme/mls_animations.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 单个步骤
class MlsStepData {
  /// 步骤标签 (如 "申请" "同意" "带看")
  final String label;

  /// 完成时显示在节点圆里的 icon (默认 Icons.check)
  final IconData? doneIcon;

  /// 显式标号 (默认无, 使用 currentIndex 计算; 用于当前节点显示数字如 "5")
  final String? badge;

  const MlsStepData({
    required this.label,
    this.doneIcon,
    this.badge,
  });
}

/// MLS 进度链 Stepper V1
///
/// N 节点水平流程链。
/// - 已完成节点: 蓝色实心圆 + 白色勾 (或 doneIcon)
/// - 当前节点:  蓝色实心圆 + 显式 badge 数字 + pulse 呼吸
/// - 未来节点:  灰色描边圆
/// 连线:
/// - 已完成段: 蓝色实线
/// - 通往当前节点的最后一段: 蓝色虚线 ("独立断开"叙事)
/// - 未来段: 灰色虚线
///
/// 用法:
/// ```
/// MlsProgressStepper(
///   steps: [
///     MlsStepData(label: '申请'),
///     MlsStepData(label: '同意'),
///     MlsStepData(label: '带看'),
///     MlsStepData(label: '发起'),
///     MlsStepData(label: '录入', badge: '5'),
///   ],
///   currentIndex: 4,  // 0-based, 第 5 节点 (录入)
/// )
/// ```
class MlsProgressStepper extends StatelessWidget {
  /// 步骤列表
  final List<MlsStepData> steps;

  /// 当前在第几步 (0-based)
  /// 0..currentIndex-1 已完成; currentIndex 当前; >currentIndex 未来
  final int currentIndex;

  /// 节点圆直径 (默认 22)
  final double nodeSize;

  /// 标签上下边距 (默认 4)
  final double labelGap;

  /// 节点完成色 (默认 success)
  final Color doneColor;

  /// 节点当前色 (默认 primary)
  final Color currentColor;

  /// 节点未来色 (默认 borderStrong)
  final Color futureColor;

  /// 是否在通往当前的最后一段用虚线 (默认 true, 叙事"独立断开")
  final bool dashedLineToCurrent;

  const MlsProgressStepper({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.nodeSize = 22,
    this.labelGap = 4,
    this.doneColor = MlsColors.success,
    this.currentColor = MlsColors.primary,
    this.futureColor = const Color(0xFFCBD5E1),
    this.dashedLineToCurrent = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      // 节点
      children.add(_buildNodeColumn(i));
      // 节点之间的连线
      if (i < steps.length - 1) {
        children.add(_buildConnector(i));
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildNodeColumn(int i) {
    final step = steps[i];
    final isDone = i < currentIndex;
    final isCurrent = i == currentIndex;

    Widget node;
    if (isDone) {
      node = Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          color: doneColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(step.doneIcon ?? Icons.check,
            size: nodeSize * 0.6, color: Colors.white),
      );
    } else if (isCurrent) {
      final core = Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          step.badge ?? '${i + 1}',
          style: TextStyle(
            fontFamily: MlsTypography.monoFamily,
            fontFamilyFallback: MlsTypography.monoFallback,
            fontSize: nodeSize * 0.45,
            fontWeight: MlsTypography.bold,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      );
      node = MlsPulse(
        pulseColor: currentColor,
        maxRadius: nodeSize + 8,
        child: core,
      );
    } else {
      node = Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: futureColor, width: 1.5),
        ),
      );
    }

    final isCurrentStep = i == currentIndex;
    return Expanded(
      flex: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          node,
          SizedBox(height: labelGap),
          Text(
            step.label,
            style: TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 9.5,
              color: isCurrentStep
                  ? currentColor
                  : (i < currentIndex
                      ? const Color(0xFF475569)
                      : MlsColors.textTertiary),
              fontWeight: isCurrentStep
                  ? MlsTypography.semibold
                  : MlsTypography.regular,
              letterSpacing: 0.5,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(int leftNodeIndex) {
    final isAllDone = leftNodeIndex + 1 < currentIndex;
    final isToCurrent = leftNodeIndex + 1 == currentIndex;
    final isFuture = leftNodeIndex >= currentIndex;

    Color color;
    bool dashed;

    if (isAllDone) {
      color = doneColor;
      dashed = false;
    } else if (isToCurrent) {
      color = dashedLineToCurrent ? futureColor : doneColor;
      dashed = dashedLineToCurrent;
    } else {
      color = futureColor;
      dashed = true;
    }

    return Expanded(
      flex: 1,
      child: Padding(
        padding: EdgeInsets.only(top: nodeSize / 2 - 0.75),
        child: dashed
            ? _DashedLine(color: color)
            : Container(height: 1.5, color: color),
      ),
    );
  }
}

/// 一条水平虚线 (CustomPaint)
class _DashedLine extends StatelessWidget {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const _DashedLine({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, strokeWidth),
      painter: _DashedLinePainter(
        color: color,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final next = (x + dashLength).clamp(0, size.width).toDouble();
      canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      x = next + gapLength;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
