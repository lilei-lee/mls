import 'package:flutter/material.dart';

/// 协作进度条组件 · Day 13 新建
///
/// 用 6 个圆点 + 连线展示协作的完整生命周期阶段:
/// 申请 → 已通过 → 带看 → 成交 → 付款 → 完成
///
/// 用法:
///   ProgressTracker(
///     stage: 2,           // 当前在第几阶段(0-5)
///     stageStatus: 'in_progress',
///     isFailed: false,
///   )
class ProgressTracker extends StatelessWidget {
  /// 当前阶段索引(0-5)
  final int stage;

  /// 'in_progress' / 'done' / 'failed' / 'expired'
  final String stageStatus;

  /// 是否进入异常终止态
  final bool isFailed;

  /// 总阶段数(默认 6)
  final int total;

  /// 阶段标签(默认 6 个中文)
  final List<String> labels;

  ProgressTracker({
    super.key,
    required this.stage,
    required this.stageStatus,
    required this.isFailed,
    this.total = 6,
  }) : labels = const ['申请', '已通过', '带看', '成交', '付款', '完成'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 圆点 + 连线区
        SizedBox(
          height: 22,
          child: Row(
            children: List.generate(total * 2 - 1, (i) {
              if (i.isEven) {
                final dotIdx = i ~/ 2;
                return _buildDot(dotIdx);
              } else {
                final lineIdx = (i - 1) ~/ 2;
                return Expanded(child: _buildLine(lineIdx));
              }
            }),
          ),
        ),
        const SizedBox(height: 4),
        // 标签区
        Row(
          children: List.generate(total, (i) {
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: _labelColor(i),
                  fontWeight: i == stage ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ===== 圆点 =====

  Widget _buildDot(int idx) {
    final color = _dotColor(idx);
    final filled = idx <= stage;

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: idx < stage
          ? const Icon(Icons.check, size: 8, color: Colors.white)
          : null,
    );
  }

  Color _dotColor(int idx) {
    if (idx > stage) return Colors.grey.shade400;
    if (idx == stage) {
      if (isFailed) return Colors.red;
      if (stageStatus == 'expired') return Colors.grey;
      if (stageStatus == 'done' && stage == 5) return Colors.green;
      return Colors.blue;
    }
    return Colors.green; // idx < stage,已完成
  }

  // ===== 连线 =====

  Widget _buildLine(int idx) {
    // 连线连接 idx 和 idx+1
    final isCompleted = idx < stage;
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: isCompleted ? Colors.green : Colors.grey.shade300,
    );
  }

  // ===== 标签颜色 =====

  Color _labelColor(int idx) {
    if (idx > stage) return Colors.grey.shade400;
    if (idx == stage) {
      if (isFailed) return Colors.red;
      if (stageStatus == 'expired') return Colors.grey;
      if (stageStatus == 'done' && stage == 5) return Colors.green;
      return Colors.blue;
    }
    return Colors.green;
  }
}