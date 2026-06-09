import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 字段壳 V1
///
/// 标签行（label + 必填* + 右侧 hint）+ 下接 child，纵向 gap 7。
///
/// 用法:
/// ```dart
/// MlsField(label: '小区名称', required: true, hint: '例：万达华府', child: MlsTextInput(...))
/// ```
class MlsField extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final Widget child;

  const MlsField({
    super.key,
    required this.label,
    this.required = false,
    this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: MlsColors.textSecondary,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontFamilyFallback: MlsTypography.sansFallback,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: MlsColors.danger,
                ),
              ),
            const Spacer(),
            if (hint != null)
              Text(
                hint!,
                style: TextStyle(
                  fontFamilyFallback: MlsTypography.sansFallback,
                  fontSize: 11,
                  color: MlsColors.textTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}
