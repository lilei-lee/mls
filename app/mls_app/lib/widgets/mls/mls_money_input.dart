import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_shadows.dart';
import '../../theme/mls_typography.dart';

/// MLS 价格输入框 V1
///
/// 反作弊基石场景核心: 成交价独立录入。
/// 视觉钩子:
/// - 输入时实时格式化为千分位 (¥1,236,000)
/// - 输入后右侧浮出"≈ 123.6 万"徽章 (帮助经纪人交叉验证位数)
/// - 检测到"万"字, 立即红色警告"请勿填万元，直接填元"
/// - 大字体 mono 数字, 强化严肃感
///
/// 用法:
/// ```
/// MlsMoneyInput(
///   label: '我的成交价 (元)',
///   onChanged: (yuan) => setState(...),  // 回调纯数字, 单位为元
///   placeholder: '例 1,236,000',
/// )
///
/// // 受控
/// MlsMoneyInput(
///   controller: _ctrl,
///   onSubmitted: () => _submit(),
/// )
/// ```
class MlsMoneyInput extends StatefulWidget {
  /// 顶部标签 (如 "我的成交价 (元)")
  final String? label;

  /// 占位符
  final String? placeholder;

  /// 初始值 (纯数字, 单位元)
  final int? initialValue;

  /// 受控 controller (与 initialValue 二选一)
  final TextEditingController? controller;

  /// 值变化回调 (纯数字, 单位元; 空输入回调 0)
  final ValueChanged<int>? onChanged;

  /// 回车提交
  final VoidCallback? onSubmitted;

  /// 是否启用 (默认 true)
  final bool enabled;

  /// 最大数字位数 (不含逗号; 默认 11 位, 即 ≤9 千万亿元, 防御性)
  final int maxDigits;

  /// 是否使用深色面板样式 (反作弊基石内嵌时用)
  final bool onDark;

  const MlsMoneyInput({
    super.key,
    this.label,
    this.placeholder,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxDigits = 11,
    this.onDark = false,
  });

  @override
  State<MlsMoneyInput> createState() => _MlsMoneyInputState();
}

class _MlsMoneyInputState extends State<MlsMoneyInput> {
  late final TextEditingController _ctrl;
  late final bool _ownsCtrl;
  late final _ThousandsFormatter _formatter;

  String _wanHint = '';
  String? _warning;

  @override
  void initState() {
    super.initState();
    _ownsCtrl = widget.controller == null;
    _ctrl = widget.controller ??
        TextEditingController(
          text: widget.initialValue != null
              ? _format(widget.initialValue!)
              : '',
        );
    _formatter = _ThousandsFormatter(maxDigits: widget.maxDigits);
    _ctrl.addListener(_onTextChanged);
    _recomputeHint(_ctrl.text);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    if (_ownsCtrl) _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _recomputeHint(_ctrl.text);
    final yuan = _parse(_ctrl.text);
    widget.onChanged?.call(yuan);
  }

  void _recomputeHint(String text) {
    // 警告: 包含汉字"万"
    if (text.contains('万')) {
      setState(() {
        _warning = '请勿填写"万"字，直接填元数。';
        _wanHint = '';
      });
      return;
    }
    final yuan = _parse(text);
    if (yuan <= 0) {
      setState(() {
        _wanHint = '';
        _warning = null;
      });
      return;
    }
    final wan = yuan / 10000.0;
    final formatted = wan >= 10000
        ? wan.toStringAsFixed(0)
        : wan.toStringAsFixed(1);
    setState(() {
      _wanHint = '≈ $formatted 万';
      _warning = null;
    });
  }

  String _format(int yuan) {
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  int _parse(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.onDark;
    final hasWarning = _warning != null;

    final fieldFg = isDark ? Colors.white : MlsColors.textPrimary;
    final fieldBg = isDark
        ? Colors.white.withOpacity(0.05)
        : MlsColors.bgCardPrimary;
    final borderColor = hasWarning
        ? MlsColors.danger
        : (isDark
            ? Colors.white.withOpacity(0.12)
            : MlsColors.borderStrong);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 12,
              color: isDark
                  ? MlsColors.textOnDarkMuted
                  : MlsColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: MlsRadius.input,
                border: Border.all(
                  color: borderColor,
                  width: hasWarning ? 1.2 : 0.5,
                ),
                boxShadow: isDark ? null : MlsShadows.sm,
              ),
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '¥',
                    style: TextStyle(
                      fontFamily: MlsTypography.monoFamily,
                      fontFamilyFallback: MlsTypography.monoFallback,
                      fontSize: 18,
                      fontWeight: MlsTypography.medium,
                      color: isDark
                          ? Colors.white.withOpacity(0.7)
                          : MlsColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [_formatter],
                      onSubmitted: (_) => widget.onSubmitted?.call(),
                      style: TextStyle(
                        fontFamily: MlsTypography.monoFamily,
                        fontFamilyFallback: MlsTypography.monoFallback,
                        fontSize: 20,
                        fontWeight: MlsTypography.semibold,
                        color: fieldFg,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: widget.placeholder ?? '例 1,236,000',
                        hintStyle: TextStyle(
                          fontFamily: MlsTypography.monoFamily,
                          fontFamilyFallback:
                              MlsTypography.monoFallback,
                          fontSize: 18,
                          fontWeight: MlsTypography.regular,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : MlsColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  if (_wanHint.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? MlsColors.primary.withOpacity(0.18)
                            : MlsColors.primaryBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _wanHint,
                        style: TextStyle(
                          fontFamily: MlsTypography.monoFamily,
                          fontFamilyFallback:
                              MlsTypography.monoFallback,
                          fontSize: 11,
                          fontWeight: MlsTypography.medium,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : MlsColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (hasWarning) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 13, color: MlsColors.danger),
              const SizedBox(width: 4),
              Text(
                _warning!,
                style: TextStyle(
                  fontFamilyFallback: MlsTypography.sansFallback,
                  fontSize: 11,
                  color: MlsColors.danger,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 输入时实时千分位格式化, 保留光标在用户预期位置 (尾部)
class _ThousandsFormatter extends TextInputFormatter {
  final int maxDigits;

  _ThousandsFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 提取纯数字 (允许保留汉字"万"用于警告显示, 但格式化时去掉)
    final raw = newValue.text;
    final hasWan = raw.contains('万');
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue(
        text: hasWan ? '万' : '',
        selection: TextSelection.collapsed(offset: hasWan ? 1 : 0),
      );
    }

    final trimmed =
        digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) buf.write(',');
      buf.write(trimmed[i]);
    }
    final formatted = hasWan ? '${buf.toString()}万' : buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
