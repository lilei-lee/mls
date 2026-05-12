import 'package:flutter/material.dart';
import 'mls_colors.dart';

/// MLS 字体系统 V1
///
/// 双字体策略:
/// - 中文/混合内容: 系统中文 sans 字体链
/// - 纯数字/英文标签/编号: JetBrains Mono (需在 pubspec.yaml 注册)
///
/// 字号阶梯:
///   26 / 24 / 22 / 17 / 16 / 14.5 / 13 / 12 / 11 / 10 / 9
///
/// 字重:
///   只用 400 / 500 / 600 / 700 四档
///
/// 使用约束:
/// - 业务代码禁止直接写 TextStyle, 必须走 MlsTypography.xxx
/// - 加新样式前先和现有阶梯核对
class MlsTypography {
  MlsTypography._();

  /// 中文 sans 字体回退链
  /// iOS → macOS → Windows → Android(HarmonyOS / Source Han / Noto) → fallback
  static const List<String> sansFallback = [
    'PingFang SC',
    '.SF UI Text',
    'HarmonyOS Sans',
    'HarmonyOS Sans SC',
    'Microsoft YaHei',
    'Source Han Sans CN',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  /// Mono 字体名(需在 pubspec.yaml 注册)
  static const String monoFamily = 'JetBrainsMono';

  /// Mono 回退链
  static const List<String> monoFallback = [
    'JetBrainsMono',
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];

  // ============ 字号 ============
  static const double xl = 26; // Hero 倒计时 / 奖金主数字
  static const double lg = 24; // metric 主数字 / 日期 picker
  static const double display = 22; // header 问候
  static const double title = 17; // 页面标题
  static const double titleSm = 16; // 卡片大标题 / Hero 房源名
  static const double subtitle = 14.5; // 待办标题
  static const double body = 13; // 正文 / section 标题
  static const double bodySm = 12; // 副文 / 描述
  static const double caption = 11; // 时间 / 辅助文字
  static const double micro = 10; // mono 标签 LIVE / REAL-TIME
  static const double tiny = 9; // 极小标签 #TD-001 / SECURED

  // ============ 字重 ============
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // ============ 内部 helper ============

  static TextStyle _sans({
    required double fontSize,
    FontWeight fontWeight = regular,
    Color color = MlsColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamilyFallback: sansFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle _mono({
    required double fontSize,
    FontWeight fontWeight = regular,
    Color color = MlsColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  // ============ 中文 sans 预设 ============

  /// 页面问候: 22px / w600 / -0.3
  static TextStyle get greeting => _sans(
        fontSize: display,
        fontWeight: semibold,
        letterSpacing: -0.3,
      );

  /// 页面标题: 17px / w600 / -0.2
  static TextStyle get pageTitle => _sans(
        fontSize: title,
        fontWeight: semibold,
        letterSpacing: -0.2,
      );

  /// 卡片大标题: 16px / w600 / -0.1
  static TextStyle get cardTitleLg => _sans(
        fontSize: titleSm,
        fontWeight: semibold,
        letterSpacing: -0.1,
      );

  /// 卡片标题: 14.5px / w500 / line-height 1.4
  static TextStyle get cardTitle => _sans(
        fontSize: subtitle,
        fontWeight: medium,
        height: 1.4,
      );

  /// 卡片副标: 12px / 灰 / line-height 1.5
  static TextStyle get cardSubtitle => _sans(
        fontSize: bodySm,
        color: MlsColors.textSecondary,
        height: 1.5,
      );

  /// section 标题: 13px / w600
  static TextStyle get sectionTitle => _sans(
        fontSize: body,
        fontWeight: semibold,
      );

  /// 正文: 13px / regular / line-height 1.5
  static TextStyle get body1 => _sans(
        fontSize: body,
        height: 1.5,
      );

  /// 小正文: 12px / regular
  static TextStyle get body2 => _sans(
        fontSize: bodySm,
        color: MlsColors.textSecondary,
      );

  /// caption: 11px / 灰
  static TextStyle get caption1 => _sans(
        fontSize: caption,
        color: MlsColors.textTertiary,
      );

  // ============ Mono 预设 ============

  /// 超大数字 (Hero/奖金主): 26px / w700 / -1
  static TextStyle get monoXl => _mono(
        fontSize: xl,
        fontWeight: bold,
        letterSpacing: -1,
      );

  /// 大数字 (metric panel): 24-26px / w600 / -0.5~1
  static TextStyle get monoLarge => _mono(
        fontSize: lg,
        fontWeight: semibold,
        letterSpacing: -0.5,
      );

  /// 中数字 (排名/等级): 22px / w700
  static TextStyle get monoMd => _mono(
        fontSize: display,
        fontWeight: bold,
        letterSpacing: -1,
      );

  /// 倒计时数字: 24px / w600 / -0.5 / line-height 1.0
  static TextStyle get countdown => _mono(
        fontSize: lg,
        fontWeight: semibold,
        letterSpacing: -0.5,
        height: 1.0,
      );

  /// metric value 文字 (在彩色卡片内): 20-22px / w700
  static TextStyle get monoMetric => _mono(
        fontSize: 20,
        fontWeight: bold,
        letterSpacing: -0.5,
      );

  /// 微数字徽章: 11px / w500
  static TextStyle get monoBadge => _mono(
        fontSize: caption,
        fontWeight: medium,
        letterSpacing: 0.5,
      );

  /// 大写标签 LIVE / REAL-TIME / PRIORITY:
  ///   10px / w500 / 1.5~2 letter-spacing / 灰
  static TextStyle get monoLabel => _mono(
        fontSize: micro,
        fontWeight: medium,
        color: MlsColors.textSecondary,
        letterSpacing: 2,
      );

  /// 大写编号 #TD-001 / SECURED / V1.0:
  ///   9px / regular / 1.5 letter / 浅灰
  static TextStyle get monoTinyLabel => _mono(
        fontSize: tiny,
        color: MlsColors.textTertiary,
        letterSpacing: 1.5,
      );

  /// 强调标签 PRIORITY · HIGH 等彩色版本: 9px / w600
  static TextStyle monoStatusLabel(Color color) => _mono(
        fontSize: tiny,
        fontWeight: semibold,
        color: color,
        letterSpacing: 1.5,
      );
}
