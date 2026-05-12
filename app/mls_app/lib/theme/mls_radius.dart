import 'package:flutter/material.dart';

/// MLS 圆角节奏系统 V1
///
/// 阶梯: 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 / pill
///
/// 元素分配:
/// - 4px:  热力图小格子
/// - 6px:  徽章 / 标签
/// - 8px:  小按钮 / 输入框
/// - 10px: 中按钮 / icon 容器 / 输入框(标准)
/// - 12px: 副卡片 / 列表项
/// - 14px: 卡片(标准)
/// - 16px: 大卡片 / 输入框(focus 态)
/// - 18px: Hero / 外容器 / 最重要的焦点
/// - pill: 圆形
class MlsRadius {
  MlsRadius._();

  // ============ 数值 ============
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xl2 = 14;
  static const double xl3 = 16;
  static const double xl4 = 18;
  static const double pill = 999;

  // ============ BorderRadius 预设 ============
  static const BorderRadius badge = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius buttonLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius input = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius listItem = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius card = BorderRadius.all(Radius.circular(xl2));
  static const BorderRadius cardLg = BorderRadius.all(Radius.circular(xl3));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(xl4));
  static const BorderRadius circle = BorderRadius.all(Radius.circular(pill));
}
