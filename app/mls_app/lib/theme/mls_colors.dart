import 'package:flutter/material.dart';

/// MLS 颜色系统 V1
///
/// 设计原则:
/// - 浅色暖灰为底,白卡浮起,深色面板做严肃焦点(反作弊基石/等级)
/// - 主色蓝 #2563eb 一以贯之,奖金区独立暖橙金色域
/// - 状态色克制: 4 个(蓝/绿/橙/红)
/// - 协作头像 5 色系交替,强化"人感"
///
/// 使用约束:
/// - 业务代码禁止硬编码 Color(0xFF...), 必须走 MlsColors.xxx
/// - 加新色前先和现有色系核对(避免色阶碎片化)
class MlsColors {
  MlsColors._();

  // ============ 背景层 ============

  /// 页面底色 - 暖灰浅(渐变起点) #EEECE4
  static const Color bgPageStart = Color(0xFFEEECE4);

  /// 页面底色 - 暖灰浅(渐变终点) #E8E5DB
  static const Color bgPageEnd = Color(0xFFE8E5DB);

  /// 卡片主底 - 纯白
  static const Color bgCardPrimary = Color(0xFFFFFFFF);

  /// 卡片副底 - 微冷白(用于卡片 160 度渐变终点,营造立体感)
  static const Color bgCardSecondary = Color(0xFFFAFAF7);

  /// 输入框背景 - 渐变起点
  static const Color bgInputStart = Color(0xFFF8FAFC);

  /// 输入框背景 - 渐变终点
  static const Color bgInputEnd = Color(0xFFF1F5F9);

  /// 深色面板底 - 反作弊基石 / 等级卡片 / 严肃按钮
  static const Color bgPanelDark = Color(0xFF0F172A);

  /// 深色面板渐变终点
  static const Color bgPanelDarkEnd = Color(0xFF1E293B);

  // ============ 文字层 ============

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  /// 深色面板上的主文字
  static const Color textOnDark = Color(0xFFE8EAED);

  /// 深色面板上的副文字
  static const Color textOnDarkMuted = Color(0xFFCBD5E1);

  /// 深色面板上的弱文字
  static const Color textOnDarkSubtle = Color(0xFF94A3B8);

  // ============ 主色 ============

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);

  /// 主色背景填充 (8% 透明)
  static const Color primaryBg = Color(0x142563EB);

  // ============ 状态色 ============

  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0x1410B981);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0x14F59E0B);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0x14DC2626);
  static const Color dangerDark = Color(0xFFB91C1C);

  static const Color info = Color(0xFF2563EB);

  // ============ 奖金 & 等级 ============

  /// 奖金主色 - 暖橙金
  static const Color gold = Color(0xFFD97706);

  /// 奖金浅色(装饰/进度条次色)
  static const Color goldLight = Color(0xFFFBBF24);

  /// 奖金背景渐变起点
  static const Color goldBgStart = Color(0xFFFEFCE8);

  /// 奖金背景渐变终点
  static const Color goldBgEnd = Color(0xFFFEF3C7);

  /// 奖金文字深色(主)
  static const Color goldTextDark = Color(0xFF78350F);

  /// 奖金文字中色(副)
  static const Color goldTextMid = Color(0xFFB45309);

  /// 等级 - 黄金
  static const Color levelGold = Color(0xFFEAB308);

  /// 等级 - 白银
  static const Color levelSilver = Color(0xFF94A3B8);

  /// 等级 - 青铜
  static const Color levelBronze = Color(0xFF92400E);

  // ============ 在线状态 ============

  static const Color online = Color(0xFF22C55E);
  static const Color away = Color(0xFF9CA3AF);

  // ============ 边框 ============

  /// 极淡边框 6% (默认)
  static const Color borderLight = Color(0x0F0F172A);

  /// 中等边框 8% (hover/emphasis)
  static const Color borderMid = Color(0x140F172A);

  /// 强边框 15% (分割线/重要边)
  static const Color borderStrong = Color(0x260F172A);

  /// 深色面板上的边框 8% white
  static const Color borderOnDark = Color(0x14FFFFFF);

  // ============ Dashboard / Charts ============

  /// Dashboard 整页底色 (#06173B)
  static const Color bgDashboard = Color(0xFF06173B);

  /// Dashboard 卡片底色 (#0A234E)
  static const Color bgCardDark = Color(0xFF0A234E);

  /// Dashboard 卡片边框 (#185FA5)
  static const Color borderCard = Color(0xFF185FA5);

  /// 双折线紫色 (#AFA9EC)
  static const Color chartPurple = Color(0xFFAFA9EC);

  /// 双折线橙色 (#EF9F27)
  static const Color chartOrange = Color(0xFFEF9F27);

  // ============ 协作头像色系 (5 个) ============
  // 用于协作 row / 协作伙伴榜 头像
  // 每个协作伙伴一个色系,避免单调,强化"人感"
  // 按 hash(姓氏) % 5 分配,后端约定一致

  /// 黄系 - 默认李姓
  static const Color avatarYellow = Color(0xFFFBBF24);
  static const Color avatarYellowLight = Color(0xFFFDE68A);
  static const Color avatarYellowText = Color(0xFF78350F);

  /// 紫系 - 默认王姓
  static const Color avatarPurple = Color(0xFFA78BFA);
  static const Color avatarPurpleLight = Color(0xFFC4B5FD);
  static const Color avatarPurpleText = Color(0xFF3730A3);

  /// 蓝系 - 默认周姓
  static const Color avatarBlue = Color(0xFF60A5FA);
  static const Color avatarBlueLight = Color(0xFFBFDBFE);
  static const Color avatarBlueText = Color(0xFF1E3A8A);

  /// 粉系 - 默认陈姓
  static const Color avatarPink = Color(0xFFF472B6);
  static const Color avatarPinkLight = Color(0xFFFBCFE8);
  static const Color avatarPinkText = Color(0xFF831843);

  /// 绿系 - 默认杨姓
  static const Color avatarGreen = Color(0xFF34D399);
  static const Color avatarGreenLight = Color(0xFFA7F3D0);
  static const Color avatarGreenText = Color(0xFF064E3B);

  /// 头像色系数组(供 hash 取色用)
  static const List<AvatarColorSet> avatarPalette = [
    AvatarColorSet(avatarYellow, avatarYellowLight, avatarYellowText),
    AvatarColorSet(avatarPurple, avatarPurpleLight, avatarPurpleText),
    AvatarColorSet(avatarBlue, avatarBlueLight, avatarBlueText),
    AvatarColorSet(avatarPink, avatarPinkLight, avatarPinkText),
    AvatarColorSet(avatarGreen, avatarGreenLight, avatarGreenText),
  ];

  /// 根据姓名取头像色系(hash % 5)
  static AvatarColorSet avatarColorFor(String name) {
    if (name.isEmpty) return avatarPalette[0];
    return avatarPalette[name.codeUnitAt(0) % avatarPalette.length];
  }

  // ============ 渐变 ============

  /// 页面背景渐变(顶到底)
  static const LinearGradient pageBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgPageStart, bgPageEnd],
  );

  /// 卡片立体渐变 - 160° 方向(略向右下) + 微冷白终点
  /// 配合 inset 高光制造玻璃质感
  static const LinearGradient cardElevated = LinearGradient(
    begin: Alignment(-0.7, -1), // 约 160°
    end: Alignment(0.7, 1),
    colors: [bgCardPrimary, bgCardSecondary],
  );

  /// Hero 蓝色渐变(135°)
  static const LinearGradient heroBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
    stops: [0.0, 0.6, 1.0],
  );

  /// 奖金暖橙金渐变(160°)
  static const LinearGradient goldBg = LinearGradient(
    begin: Alignment(-0.7, -1),
    end: Alignment(0.7, 1),
    colors: [bgCardPrimary, goldBgStart, goldBgEnd],
    stops: [0.0, 0.5, 1.0],
  );

  /// 深色面板渐变(135°) - 反作弊基石/等级用
  static const LinearGradient panelDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgPanelDark, bgPanelDarkEnd],
  );

  /// 输入框背景渐变
  static const LinearGradient inputBg = LinearGradient(
    begin: Alignment(-0.7, -1),
    end: Alignment(0.7, 1),
    colors: [bgInputStart, bgInputEnd],
  );

  /// 主按钮 - 蓝色渐变 (CTA 用)
  static const LinearGradient buttonBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );

  /// 主按钮 - 深色渐变 (严肃感,如成交确认提交)
  static const LinearGradient buttonDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgPanelDark, bgPanelDarkEnd],
  );

  /// 主按钮 - 危险渐变 (立即处理类)
  static const LinearGradient buttonDanger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [danger, dangerDark],
  );
}

/// 协作头像色系套装
class AvatarColorSet {
  /// 主色 (强)
  final Color primary;

  /// 浅色 (用于头像背景渐变起点)
  final Color light;

  /// 文字色 (用于头像中字母)
  final Color text;

  const AvatarColorSet(this.primary, this.light, this.text);

  /// 头像背景渐变 (145°)
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, primary],
      );
}
