import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 在线状态
enum MlsOnlineStatus {
  /// 不显示在线点
  none,

  /// 在线 (绿色)
  online,

  /// 离开/最近不在线 (灰色)
  away,
}

/// MLS 渐变头像 V1
///
/// 头像背景按姓氏 hash 取 5 色系之一 (李/王/周/陈/杨...), 强化"人感"。
/// 可选右下角在线点 (绿/灰)。
///
/// 业务用法:
/// ```
/// MlsAvatar(name: '李红')                                    // 36px, 黄系, 无在线点
/// MlsAvatar(name: '张三', size: 42)                          // 42px
/// MlsAvatar(name: '李红', onlineStatus: MlsOnlineStatus.online)  // 带绿点
/// MlsAvatar(name: '李红', borderWidth: 2, borderColor: ...)  // 协作 row 里的白边
/// ```
class MlsAvatar extends StatelessWidget {
  /// 姓名 (取首字显示, 按 hash 取色)
  final String name;

  /// 直径 (默认 36)
  final double size;

  /// 在线状态 (默认 none)
  final MlsOnlineStatus onlineStatus;

  /// 不依赖 hash, 强制用指定色系 (传 null 走 hash)
  final AvatarColorSet? overrideColorSet;

  /// 外边框宽度 (默认 0)
  /// 协作 row 里头像叠在一起时, 用 2 px 白边分割
  final double borderWidth;

  /// 外边框颜色 (默认 bgCardPrimary 白色)
  final Color? borderColor;

  /// 在线点直径 (默认 = size * 0.28, 范围 8~13)
  final double? onlineDotSize;

  /// 在线点边框宽度 (默认 2, 用于和背景分离)
  final double onlineDotBorderWidth;

  /// 在线点边框色 (默认 bgPageStart, 跟页面底色融合)
  final Color? onlineDotBorderColor;

  /// 点击回调
  final VoidCallback? onTap;

  const MlsAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.onlineStatus = MlsOnlineStatus.none,
    this.overrideColorSet,
    this.borderWidth = 0,
    this.borderColor,
    this.onlineDotSize,
    this.onlineDotBorderWidth = 2,
    this.onlineDotBorderColor,
    this.onTap,
  });

  /// 取首字 (汉字取 1 个; 英文取首字母大写)
  /// 对房产经纪人姓名场景安全 (BMP 内字符), 不处理 emoji / surrogate pair
  String get _initial {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  AvatarColorSet get _colorSet =>
      overrideColorSet ?? MlsColors.avatarColorFor(name);

  double get _resolvedDotSize {
    if (onlineDotSize != null) return onlineDotSize!;
    final d = size * 0.28;
    return d.clamp(8, 13);
  }

  Color get _onlineDotColor {
    switch (onlineStatus) {
      case MlsOnlineStatus.online:
        return MlsColors.online;
      case MlsOnlineStatus.away:
        return MlsColors.away;
      case MlsOnlineStatus.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorSet = _colorSet;
    final fontSize = size * 0.36; // 36px 头像 → 13 字号

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: colorSet.gradient,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? MlsColors.bgCardPrimary,
                width: borderWidth,
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A), // 10% black
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          fontFamilyFallback: MlsTypography.sansFallback,
          fontSize: fontSize,
          fontWeight: MlsTypography.semibold,
          color: colorSet.text,
          height: 1,
        ),
      ),
    );

    final widgetWithDot = onlineStatus == MlsOnlineStatus.none
        ? avatar
        : Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: _resolvedDotSize,
                  height: _resolvedDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _onlineDotColor,
                    border: Border.all(
                      color: onlineDotBorderColor ?? MlsColors.bgPageStart,
                      width: onlineDotBorderWidth,
                    ),
                  ),
                ),
              ),
            ],
          );

    if (onTap == null) return widgetWithDot;
    return GestureDetector(onTap: onTap, child: widgetWithDot);
  }
}

/// 协作头像横向 stack
/// 多个头像负 margin 叠在一起 + 末尾 +N 数字徽章
///
/// 用法:
/// ```
/// MlsAvatarStack(
///   names: ['李红', '王明', '周丽', '陈强', '杨敏'],
///   onlineMap: {'李红': MlsOnlineStatus.online, '陈强': MlsOnlineStatus.away},
///   moreCount: 2,
/// )
/// ```
class MlsAvatarStack extends StatelessWidget {
  /// 头像姓名列表
  final List<String> names;

  /// 每个人对应的在线状态 (key = name)
  /// 不在 map 中的默认 none
  final Map<String, MlsOnlineStatus> onlineMap;

  /// 末尾 +N 计数 (传 0 不显示)
  final int moreCount;

  /// 每个头像直径 (默认 32)
  final double avatarSize;

  /// 相邻头像重叠量 (默认 -8)
  final double overlap;

  /// 头像白边宽度 (默认 2)
  final double borderWidth;

  /// 边框色 (默认 bgCardPrimary 白)
  final Color? borderColor;

  const MlsAvatarStack({
    super.key,
    required this.names,
    this.onlineMap = const {},
    this.moreCount = 0,
    this.avatarSize = 32,
    this.overlap = -8,
    this.borderWidth = 2,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    // 用 Stack + Positioned 实现重叠 (Flutter Padding 不支持负 EdgeInsets)
    final widgets = <Widget>[];
    for (var i = 0; i < names.length; i++) {
      final n = names[i];
      widgets.add(MlsAvatar(
        name: n,
        size: avatarSize,
        onlineStatus: onlineMap[n] ?? MlsOnlineStatus.none,
        borderWidth: borderWidth,
        borderColor: borderColor,
      ));
    }
    if (moreCount > 0) {
      widgets.add(Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x0D0F172A), // 5% black
          border: Border.all(
            color: borderColor ?? MlsColors.bgCardPrimary,
            width: borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '+$moreCount',
          style: MlsTypography.monoBadge.copyWith(
            color: MlsColors.textSecondary,
            fontWeight: MlsTypography.medium,
          ),
        ),
      ));
    }
    // 相邻中心距 stride = avatarSize + overlap (overlap=-8 时 stride=24)
    final stride = avatarSize + overlap;
    final totalWidth = widgets.isEmpty
        ? 0.0
        : avatarSize + stride * (widgets.length - 1);
    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < widgets.length; i++)
            Positioned(
              left: stride * i,
              child: widgets[i],
            ),
        ],
      ),
    );
  }
}
