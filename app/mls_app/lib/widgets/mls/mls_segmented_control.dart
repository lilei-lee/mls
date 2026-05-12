import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 分段控件视觉变体
enum MlsSegmentedVariant {
  /// 灰底药丸 + 白滑块 (仪表盘"本月 / 本季 / 今年")
  pill,

  /// 下划线 (协作 Tab "买方/卖方")
  underline,
}

/// MLS 分段切换 V1
///
/// 用于在几个互斥维度之间切换 (时间维度 / 角色视图 / 列表过滤 等)。
/// 不依赖外部 ValueNotifier, 一个 selected + onChanged 即可工作。
///
/// 用法 (pill):
/// ```
/// MlsSegmentedControl<String>(
///   values: ['本月', '本季', '今年'],
///   selected: '本月',
///   onChanged: (v) => setState(...),
/// )
/// ```
///
/// 用法 (underline, 协作 Tab):
/// ```
/// MlsSegmentedControl<String>(
///   values: ['买方协作', '卖方协作'],
///   selected: ...,
///   onChanged: ...,
///   variant: MlsSegmentedVariant.underline,
/// )
/// ```
class MlsSegmentedControl<T> extends StatelessWidget {
  /// 选项 (内容唯一, 用 == 判断)
  final List<T> values;

  /// 当前选中
  final T selected;

  /// 切换回调
  final ValueChanged<T> onChanged;

  /// 选项的显示文字 (默认调用 toString)
  /// 比如 values 是 enum, 这里就传枚举到中文名的映射
  final String Function(T)? labelOf;

  /// 视觉变体 (默认 pill)
  final MlsSegmentedVariant variant;

  /// 是否撑满宽度 (underline 用 true; pill 用 false 居中或居左)
  final bool fullWidth;

  const MlsSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    this.variant = MlsSegmentedVariant.pill,
    this.fullWidth = false,
  });

  String _label(T v) => labelOf?.call(v) ?? v.toString();

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case MlsSegmentedVariant.pill:
        return _buildPill(context);
      case MlsSegmentedVariant.underline:
        return _buildUnderline(context);
    }
  }

  /// pill 版本: 灰底外壳 + 选中白滑块 + 阴影
  Widget _buildPill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x0D0F172A), // 5% black
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: values.map((v) {
          final isSelected = v == selected;
          return _PillItem(
            label: _label(v),
            selected: isSelected,
            expand: fullWidth,
            onTap: () => onChanged(v),
          );
        }).toList(),
      ),
    );
  }

  /// underline 版本: 选项横排 + 选中底部 2 px 蓝色短线
  Widget _buildUnderline(BuildContext context) {
    return Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: values.map((v) {
        final isSelected = v == selected;
        return _UnderlineItem(
          label: _label(v),
          selected: isSelected,
          expand: fullWidth,
          onTap: () => onChanged(v),
        );
      }).toList(),
    );
  }
}

class _PillItem extends StatelessWidget {
  final String label;
  final bool selected;
  final bool expand;
  final VoidCallback onTap;

  const _PillItem({
    required this.label,
    required this.selected,
    required this.expand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? MlsColors.bgCardPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamilyFallback: MlsTypography.sansFallback,
            fontSize: 11,
            fontWeight: selected
                ? MlsTypography.semibold
                : MlsTypography.regular,
            color: selected ? MlsColors.textPrimary : MlsColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
    return expand ? Expanded(child: child) : child;
  }
}

class _UnderlineItem extends StatelessWidget {
  final String label;
  final bool selected;
  final bool expand;
  final VoidCallback onTap;

  const _UnderlineItem({
    required this.label,
    required this.selected,
    required this.expand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 14,
                fontWeight: selected
                    ? MlsTypography.semibold
                    : MlsTypography.regular,
                color: selected
                    ? MlsColors.primary
                    : MlsColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 2,
              width: selected ? 32 : 0,
              decoration: BoxDecoration(
                color: MlsColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? Expanded(child: child) : child;
  }
}
