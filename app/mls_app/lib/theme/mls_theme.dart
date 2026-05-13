import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mls_colors.dart';
import 'mls_typography.dart';
import 'mls_radius.dart';

/// MLS 主题汇总 V1
///
/// 用法 (main.dart):
/// ```
/// MaterialApp(
///   theme: MlsTheme.light,
///   home: ...,
/// )
/// ```
///
/// 注: 这里只覆盖 Flutter 内置控件的默认主题 (AppBar / Card / Input / Button 等)
///     业务自定义组件(MlsCard / MlsHeroToday 等)不依赖 ThemeData,
///     直接走 MlsColors / MlsTypography / MlsShadows / MlsRadius
class MlsTheme {
  MlsTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,

        // ============ 主色 ============
        primaryColor: MlsColors.primary,
        scaffoldBackgroundColor: MlsColors.bgPageStart,
        canvasColor: MlsColors.bgPageStart,

        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: MlsColors.primary,
          onPrimary: Colors.white,
          secondary: MlsColors.gold,
          onSecondary: Colors.white,
          error: MlsColors.danger,
          onError: Colors.white,
          surface: MlsColors.bgCardPrimary,
          onSurface: MlsColors.textPrimary,
        ),

        // ============ 字体 fallback ============
        fontFamilyFallback: MlsTypography.sansFallback,

        // ============ AppBar ============
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: MlsTypography.pageTitle,
          iconTheme: const IconThemeData(
            color: MlsColors.textPrimary,
            size: 20,
          ),
        ),

        // ============ 文字主题 (兜底, 优先用 MlsTypography 取样式) ============
        textTheme: TextTheme(
          displayLarge: MlsTypography.greeting,
          headlineMedium: MlsTypography.pageTitle,
          titleLarge: MlsTypography.cardTitleLg,
          titleMedium: MlsTypography.cardTitle,
          bodyLarge: MlsTypography.body1,
          bodyMedium: MlsTypography.body2,
          bodySmall: MlsTypography.caption1,
          labelSmall: MlsTypography.caption1,
        ),

        // ============ 卡片 (业务一般用 MlsCard, 这里只兜底原生 Card) ============
        cardTheme: const CardThemeData(
          color: MlsColors.bgCardPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: MlsRadius.card),
          margin: EdgeInsets.zero,
        ),

        // ============ 输入框 (业务用 MlsMoneyInput / MlsTextField, 这里兜底) ============
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: MlsColors.bgInputStart,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(
            borderRadius: MlsRadius.input,
            borderSide:
                BorderSide(color: MlsColors.borderMid, width: 0.5),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: MlsRadius.input,
            borderSide:
                BorderSide(color: MlsColors.borderMid, width: 0.5),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: MlsRadius.input,
            borderSide:
                BorderSide(color: MlsColors.primary, width: 1.5),
          ),
          hintStyle: MlsTypography.body2,
          labelStyle: MlsTypography.body2,
        ),

        // ============ ElevatedButton (兜底) ============
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: MlsColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: MlsRadius.button,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 13.5,
              fontWeight: MlsTypography.semibold,
            ),
          ),
        ),

        // ============ TextButton (兜底) ============
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: MlsColors.primary,
            textStyle: const TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 13,
              fontWeight: MlsTypography.medium,
            ),
          ),
        ),

        // ============ 分隔线 ============
        dividerTheme: const DividerThemeData(
          color: MlsColors.borderLight,
          thickness: 0.5,
          space: 0,
        ),

        // ============ Checkbox ============
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return MlsColors.primary;
            }
            return MlsColors.bgCardPrimary;
          }),
          checkColor:
              const WidgetStatePropertyAll(Colors.white),
          side: const BorderSide(color: MlsColors.borderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MlsRadius.sm),
          ),
        ),

        // ============ Switch ============
        switchTheme: SwitchThemeData(
          thumbColor:
              const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return MlsColors.primary;
            }
            return MlsColors.borderStrong;
          }),
        ),

        // ============ SnackBar ============
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: MlsColors.bgPanelDark,
          contentTextStyle: TextStyle(
            fontFamilyFallback: MlsTypography.sansFallback,
            color: MlsColors.textOnDark,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: MlsRadius.button,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
