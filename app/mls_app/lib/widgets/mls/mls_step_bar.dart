import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 单步数据
class MlsStepBarItem {
  final String label;
  const MlsStepBarItem({required this.label});
}

/// 表单步骤条 V1
///
/// 圆 + 连线 + 标签，用于多步表单顶部。
///
/// 用法:
/// ```dart
/// MlsStepBar(
///   steps: [
///     MlsStepBarItem(label: '基本信息'),
///     MlsStepBarItem(label: '户型规格'),
///     MlsStepBarItem(label: '价格'),
///     MlsStepBarItem(label: '图片'),
///   ],
///   current: _step,
/// )
/// ```
class MlsStepBar extends StatelessWidget {
  final List<MlsStepBarItem> steps;
  final int current;

  const MlsStepBar({
    super.key,
    required this.steps,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // 连接线
          final leftDone = (i ~/ 2) < current;
          return Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Container(
                height: 1.5,
                color: leftDone ? MlsColors.primary : MlsColors.borderStrong,
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final cur = idx == current;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? MlsColors.primary
                    : cur
                        ? MlsColors.primaryBg
                        : Colors.transparent,
                border: Border.all(
                  color: cur
                      ? MlsColors.primary
                      : done
                          ? MlsColors.primary
                          : MlsColors.borderStrong,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontFamily: MlsTypography.monoFamily,
                        fontFamilyFallback: MlsTypography.monoFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cur ? MlsColors.primary : MlsColors.textTertiary,
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              steps[idx].label,
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 10.5,
                color: cur ? MlsColors.primary : MlsColors.textTertiary,
                fontWeight: cur ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }
}
