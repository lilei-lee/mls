import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 选择行 V1
///
/// 可点行，弹出 picker。左图标 + 值/占位 + 右 chevron-down。
///
/// 用法:
/// ```dart
/// MlsSelectRow(
///   leading: Icons.home_work,
///   value: decoration,
///   placeholder: '选择装修',
///   onTap: () => _showPicker(),
/// )
/// ```
class MlsSelectRow extends StatelessWidget {
  final IconData? leading;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const MlsSelectRow({
    super.key,
    this.leading,
    this.value,
    this.placeholder = '请选择',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: EdgeInsets.only(
          left: leading != null ? 40 : 12,
          right: 40,
        ),
        decoration: BoxDecoration(
          color: MlsColors.bgCardPrimary,
          borderRadius: MlsRadius.buttonLg,
          border: Border.all(color: MlsColors.borderStrong, width: 0.5),
        ),
        child: Stack(
          children: [
            if (leading != null)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Icon(leading, size: 17, color: MlsColors.textTertiary),
              ),
            Center(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hasValue ? value! : placeholder,
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 14,
                    color: hasValue ? MlsColors.textPrimary : MlsColors.textTertiary,
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Icon(Icons.keyboard_arrow_down, size: 17, color: MlsColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
