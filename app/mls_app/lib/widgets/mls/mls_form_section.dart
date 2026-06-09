import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 表单分节 V1
///
/// 可选 mono 小标题 + 内部子项纵向 gap 18。
///
/// 用法:
/// ```dart
/// MlsFormSection(
///   title: 'CONTACT',
///   children: [MlsField(...), MlsField(...)],
/// )
/// ```
class MlsFormSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final double gap;

  const MlsFormSection({
    super.key,
    this.title,
    required this.children,
    this.gap = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              fontFamily: MlsTypography.monoFamily,
              fontFamilyFallback: MlsTypography.monoFallback,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: MlsColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}
