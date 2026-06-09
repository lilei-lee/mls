import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 文本输入 V1
///
/// 单行输入。focus 时蓝描边 + 光晕。可选 leading 图标、suffix 单位、mono 字体。
///
/// 用法:
/// ```dart
/// MlsTextInput(hint: '例:108', suffix: '㎡', mono: true)
/// MlsTextInput(leading: Icons.phone, type: TextInputType.phone)
/// ```
class MlsTextInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final IconData? leading;
  final String? suffix;
  final bool mono;
  final TextInputType? type;
  final ValueChanged<String>? onChanged;

  const MlsTextInput({
    super.key,
    this.controller,
    this.hint,
    this.leading,
    this.suffix,
    this.mono = false,
    this.type,
    this.onChanged,
  });

  @override
  State<MlsTextInput> createState() => _MlsTextInputState();
}

class _MlsTextInputState extends State<MlsTextInput> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: MlsColors.bgCardPrimary,
        borderRadius: MlsRadius.buttonLg,
        border: Border.all(
          color: _focused ? MlsColors.primary : MlsColors.borderStrong,
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: MlsColors.primaryBg,
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.only(
        left: widget.leading != null ? 40 : 12,
        right: widget.suffix != null ? 48 : 12,
      ),
      child: Stack(
        children: [
          if (widget.leading != null)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Icon(widget.leading, size: 17, color: MlsColors.textTertiary),
            ),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.type,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontFamily: widget.mono ? MlsTypography.monoFamily : null,
              fontFamilyFallback: widget.mono
                  ? MlsTypography.monoFallback
                  : MlsTypography.sansFallback,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: MlsColors.textPrimary,
              fontFeatures: widget.mono ? const [FontFeature.tabularFigures()] : null,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 14,
                color: MlsColors.textTertiary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              isCollapsed: true,
            ),
          ),
          if (widget.suffix != null)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  widget.suffix!,
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 13,
                    color: MlsColors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
