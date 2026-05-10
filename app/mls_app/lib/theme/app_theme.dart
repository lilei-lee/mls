/// MLS Design System v2.0 — "立体科技 · 商家工具"
/// 双主色 + Surface 4 层 + Shadow 5 级 + Gradients 3 种 + Lucide icons
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ═══ 双主色 ═══
  // 科技深蓝
  static const Color primary50 = Color(0xFFE6EDFF);
  static const Color primary100 = Color(0xFFCCD9FF);
  static const Color primary500 = Color(0xFF2E5BFF);
  static const Color primary600 = Color(0xFF1E47E8);
  static const Color primary900 = Color(0xFF0F1F66);

  // 财富金
  static const Color gold50 = Color(0xFFFFF9E6);
  static const Color gold500 = Color(0xFFF5A623);
  static const Color gold600 = Color(0xFFE0941A);

  // ═══ 中性色 10 阶 ═══
  static const Color n0 = Color(0xFFFFFFFF);
  static const Color n50 = Color(0xFFF8FAFC);
  static const Color n100 = Color(0xFFEEF1F5);
  static const Color n150 = Color(0xFFE2E7EE);
  static const Color n200 = Color(0xFFCDD3DC);
  static const Color n300 = Color(0xFFA8B0BD);
  static const Color n500 = Color(0xFF6B7280);
  static const Color n700 = Color(0xFF374151);
  static const Color n800 = Color(0xFF1F2937);
  static const Color n900 = Color(0xFF0B1220);

  // ═══ 功能色 ═══
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // 点缀色
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);

  // ═══ Surface 4 层 ═══
  static const Color surface0 = n0;
  static const Color surface1 = n50;
  static const Color surface2 = n0;
  static const Color surface3 = n0;

  // ═══ Shadow 5 级 ═══
  static const List<BoxShadow> shadowHero = [
    BoxShadow(offset: Offset(0, 6), blurRadius: 16, color: Color(0x1F2E5BFF)),
    BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0x0F0F1F66)),
  ];
  static const List<BoxShadow> shadowGold = [
    BoxShadow(offset: Offset(0, 6), blurRadius: 16, color: Color(0x29F5A623)),
    BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0x14E0941A)),
  ];
  static const List<BoxShadow> shadowCard = [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x0A0B1220)),
    BoxShadow(offset: Offset(0, 3), blurRadius: 8, color: Color(0x0A0B1220)),
  ];
  static const List<BoxShadow> shadowFloat = [
    BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color(0x1A0B1220)),
  ];
  static const List<BoxShadow> shadowBtn = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0x332E5BFF)),
  ];

  // ═══ Radius 5 档 ═══
  static const double radiusS = 6;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;
  static const double radiusPill = 999;

  // ═══ Spacing 8dp 网格 ═══
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ═══ TextStyles ═══
  static const TextStyle display = TextStyle(fontSize: 28, height: 1.29, fontWeight: FontWeight.w700, color: n900);
  static const TextStyle titleL = TextStyle(fontSize: 22, height: 1.36, fontWeight: FontWeight.w700, color: n900);
  static const TextStyle titleM = TextStyle(fontSize: 17, height: 1.41, fontWeight: FontWeight.w600, color: n900);
  static const TextStyle titleS = TextStyle(fontSize: 15, height: 1.47, fontWeight: FontWeight.w600, color: n900);
  static const TextStyle bodyL = TextStyle(fontSize: 15, height: 1.47, fontWeight: FontWeight.w400, color: n800);
  static const TextStyle bodyM = TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w400, color: n800);
  static const TextStyle bodyS = TextStyle(fontSize: 13, height: 1.38, fontWeight: FontWeight.w400, color: n700);
  static const TextStyle caption = TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: n500);

  // 数字专属(tabular figures)
  static const TextStyle numberXL = TextStyle(fontSize: 32, height: 1.25, fontWeight: FontWeight.w700, color: n900);
  static const TextStyle numberL = TextStyle(fontSize: 24, height: 1.33, fontWeight: FontWeight.w700, color: n900);
  static const TextStyle numberM = TextStyle(fontSize: 18, height: 1.33, fontWeight: FontWeight.w600, color: n900);

  // ═══ Gradients ═══
  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [primary500, Color(0xFF5478FF)],
  );
  static const LinearGradient gradientGold = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [gold500, Color(0xFFFFB949)],
  );
  static const LinearGradient gradientSurface = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [n0, n50],
  );

  // ═══ Status color map ═══
  static const Map<String, Color> listingStatusColor = {
    'on_sale': success,
    'deposit_paid': primary500,
    'transaction_ongoing': warning,
    'sold': n500,
    'paused': warning,
    'offline': n500,
  };
  static const Map<String, Color> collabStatusColor = {
    'pending': warning,
    'approved': info,
    'showing_done': primary500,
    'transaction_initiated': warning,
    'transaction_confirmed': success,
    'rejected': n500,
    'canceled': n500,
  };

  static ThemeData get lightTheme => ThemeData(useMaterial3: true, colorSchemeSeed: primary500, brightness: Brightness.light);
}
