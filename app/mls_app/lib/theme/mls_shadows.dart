import 'package:flutter/material.dart';

/// MLS 立体感阴影系统 V1
///
/// 阴影 = 立体感 = "想用"的核心物理感
///
/// 设计原则:
/// - 每档阴影都是"近影 + 远影"双层叠加, 制造真实漂浮感
/// - 颜色全部用深色 black 系, 而非黑色, 避免脏感
/// - 主按钮/Hero/奖金各有专用阴影
///
/// 注: Flutter 不原生支持 inset shadow
///     卡片的 inset 高光由 cardElevated 渐变背景(从亮白到微冷白)模拟,
///     不需要额外 shadow
class MlsShadows {
  MlsShadows._();

  /// 极轻阴影 - 小元素 (徽章/小卡片)
  /// 单层 1px 近影
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A0F172A), // 4% black
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// 中等阴影 - 普通卡片 (待办/快捷操作/动态流)
  /// 近影 1px + 远影 12px
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F0F172A), // 6% black
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// 强阴影 - 焦点卡片 (4-metric panel)
  /// 近影 1px + 远影 24px
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x140F172A), // 8% black
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Hero 蓝色光晕 - 今日带看大卡片
  /// 把品牌色"渗"到周围
  static const List<BoxShadow> heroBlue = [
    BoxShadow(
      color: Color(0x332563EB), // 20% primary
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x2E2563EB), // 18% primary
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// 奖金暖橙金光晕 - 仪表盘奖金卡片
  static const List<BoxShadow> goldGlow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x14D97706), // 8% gold
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// 深色面板光晕 - 反作弊基石 / 等级卡片
  static const List<BoxShadow> panelDark = [
    BoxShadow(
      color: Color(0x400F172A), // 25% black
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x2E0F172A), // 18% black
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// 危险按钮光晕 (立即处理/红色 CTA)
  static const List<BoxShadow> dangerButton = [
    BoxShadow(
      color: Color(0x40DC2626), // 25% danger
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// 主按钮蓝色光晕
  static const List<BoxShadow> primaryButton = [
    BoxShadow(
      color: Color(0x402563EB),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// 深色严肃按钮光晕 - 成交确认提交用
  static const List<BoxShadow> darkButton = [
    BoxShadow(
      color: Color(0x330F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x260F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// 底部 Nav 反向上拢阴影
  static const List<BoxShadow> navTop = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];

  /// 输入框 focus 蓝色 ring (用 spreadRadius 模拟 box-shadow ring)
  static const List<BoxShadow> focusRing = [
    BoxShadow(
      color: Color(0x192563EB), // 10% primary
      blurRadius: 0,
      spreadRadius: 3,
    ),
  ];
}
