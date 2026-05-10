import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
        hintStyle: AppTheme.caption.copyWith(color: AppTheme.n300),
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 20, color: _focused ? AppTheme.primary500 : AppTheme.n500) : null,
        suffixIcon: widget.suffixIcon != null ? GestureDetector(onTap: widget.onSuffixTap, child: Icon(widget.suffixIcon, size: 20, color: AppTheme.n500)) : null,
        filled: true,
        fillColor: _focused ? AppTheme.n0 : AppTheme.n100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM), borderSide: const BorderSide(color: AppTheme.primary500, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM), borderSide: const BorderSide(color: AppTheme.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM), borderSide: const BorderSide(color: AppTheme.danger, width: 2)),
        counterText: '',
      ),
    );
  }
}
