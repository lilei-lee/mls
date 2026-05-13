import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';

class AppInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;

  const AppInput({super.key, this.controller, this.hint, this.label, this.prefixIcon, this.suffixIcon, this.onSuffixTap, this.validator, this.keyboardType, this.maxLength, this.maxLines = 1});

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
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
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        hintStyle: AppTheme.caption.copyWith(color: MlsColors.borderStrong),
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 20, color: _focused ? MlsColors.primary : MlsColors.textSecondary) : null,
        suffixIcon: widget.suffixIcon != null ? GestureDetector(onTap: widget.onSuffixTap, child: Icon(widget.suffixIcon, size: 20, color: MlsColors.textSecondary)) : null,
        filled: true,
        fillColor: _focused ? MlsColors.bgCardPrimary : MlsColors.borderLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: MlsColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: MlsColors.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: MlsColors.danger, width: 2)),
        counterText: '',
      ),
    );
  }
}
