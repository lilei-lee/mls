import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// Chip 选择 V1
///
/// 单选/多选 chip 组，Wrap 布局。
///
/// 用法:
/// ```dart
/// // 单选
/// MlsChipSelect<String>(
///   options: ['南北通透', '朝南', '朝东'],
///   selected: _orientation,
///   onChanged: (v) => setState(() => _orientation = v),
/// )
/// // 多选
/// MlsChipSelect<String>(
///   options: ['满五唯一', '南北通透', '精装'],
///   selected: _features,
///   multi: true,
///   onChanged: (v) => setState(() => _features = v),
/// )
/// ```
class MlsChipSelect<T> extends StatelessWidget {
  final List<T> options;
  final dynamic selected; // T for single, List<T> for multi
  final ValueChanged<dynamic> onChanged;
  final bool multi;
  final String Function(T)? labelOf;

  const MlsChipSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multi = false,
    this.labelOf,
  });

  String _label(T v) => labelOf?.call(v) ?? v.toString();

  bool _isSelected(T v) {
    if (multi) {
      return (selected as List<T>).contains(v);
    }
    return selected == v;
  }

  void _handleTap(T v) {
    if (multi) {
      final list = List<T>.from(selected as List<T>);
      if (list.contains(v)) {
        list.remove(v);
      } else {
        list.add(v);
      }
      onChanged(list);
    } else {
      onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final sel = _isSelected(opt);
        return GestureDetector(
          onTap: () => _handleTap(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? MlsColors.primaryBg : MlsColors.bgCardPrimary,
              borderRadius: MlsRadius.buttonLg,
              border: Border.all(
                color: sel ? MlsColors.primary : MlsColors.borderStrong,
                width: 1,
              ),
            ),
            child: Text(
              _label(opt),
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? MlsColors.primary : MlsColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
