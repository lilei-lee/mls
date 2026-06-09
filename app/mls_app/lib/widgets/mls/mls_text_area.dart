import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 多行输入 V1
///
/// 默认 3 行，line-height 1.6，禁止拉伸。
///
/// 用法:
/// ```dart
/// MlsTextArea(hint: '补充描述...', controller: _descCtrl)
/// ```
class MlsTextArea extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final int minLines;
  final int maxLines;

  const MlsTextArea({
    super.key,
    this.controller,
    this.hint,
    this.minLines = 3,
    this.maxLines = 3,
  });

  @override
  State<MlsTextArea> createState() => _MlsTextAreaState();
}

class _MlsTextAreaState extends State<MlsTextArea> {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: TextStyle(
          fontFamilyFallback: MlsTypography.sansFallback,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: MlsColors.textPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontFamilyFallback: MlsTypography.sansFallback,
            fontSize: 14,
            color: MlsColors.textTertiary,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
        ),
      ),
    );
  }
}
