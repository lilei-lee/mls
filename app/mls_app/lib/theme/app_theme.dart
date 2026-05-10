/// V3 设计系统基建 — 颜色 / 字号 / 间距 常量
/// 当前仅定义,各文件渐进迁移时可引用
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTheme {
  AppTheme._();

  // ── 间距(8dp 网格) ──
  static const spacing4 = 4.0;
  static const spacing8 = 8.0;
  static const spacing12 = 12.0;
  static const spacing16 = 16.0;
  static const spacing24 = 24.0;
  static const spacing32 = 32.0;

  // ── 圆角 3 档语义 ──
  static const radiusSmall = 4.0;   // chip / tag
  static const radiusMedium = 8.0;  // button / input / card
  static const radiusLarge = 16.0;  // BottomSheet / Dialog

  // ── 主色 ──
  static const primaryBlue = Color(0xFF1976D2);
  static const primaryRed = Colors.red;

  // ── 中性色(grey scale) ──
  static const grey50 = Color(0xFFFAFAFA);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey200 = Color(0xFFEEEEEE);
  static const grey400 = Color(0xFFBDBDBD);
  static const grey600 = Color(0xFF757575);
  static const grey800 = Color(0xFF424242);

  // ── 状态色(房源 + 协作) ──
  static const colorOnSale = Colors.green;
  static const colorDepositPaid = Colors.blue;
  static const colorTransactionOngoing = Colors.orange;
  static const colorPending = Colors.orange;
  static const colorApproved = Colors.green;
  static const colorRejected = Colors.grey;
  static const colorTerminal = Colors.grey;
  static const colorError = Colors.red;

  // ── 字号 4 档 ──
  static const fontAppBar = 18.0;
  static const fontSectionTitle = 16.0;
  static const fontBody = 14.0;
  static const fontCaption = 12.0;
  static const fontSmall = 10.0;

  /// Material 3 light theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryBlue,
    brightness: Brightness.light,
  );
}
