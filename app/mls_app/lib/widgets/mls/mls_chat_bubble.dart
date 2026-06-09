import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_shadows.dart';
import '../../theme/mls_typography.dart';
import 'mls_avatar.dart';

/// 聊天气泡类型
enum ChatBubbleType {
  /// 我方蓝渐变右对齐
  mine,

  /// 对方白卡左对齐
  other,

  /// 系统事件居中胶囊
  system,
}

/// 聊天气泡 V1
///
/// 我方蓝渐变右 / 对方白卡左 / 系统事件居中。可选内嵌房源卡、带看邀请卡。
///
/// 用法:
/// ```dart
/// MlsChatBubble(
///   type: ChatBubbleType.mine,
///   text: '王先生想看看万达华府',
///   time: '14:30',
/// )
/// MlsChatBubble.listingCard(...)
/// MlsChatBubble.showingInvite(accepted: _accepted, onAccept: () => ...)
/// ```
class MlsChatBubble extends StatelessWidget {
  final ChatBubbleType type;
  final String? text;
  final String? time;
  final String? avatarName;
  final Widget? child; // 自定义内容（房源卡 / 带看邀请卡等）

  const MlsChatBubble({
    super.key,
    required this.type,
    this.text,
    this.time,
    this.avatarName,
    this.child,
  });

  /// 内嵌房源卡（对方发送）
  factory MlsChatBubble.listingCard({
    required String listingName,
    required String priceWan,
    required String areaSqm,
    required String time,
    required String avatarName,
    required VoidCallback onTap,
    List<String>? tags,
  }) {
    return MlsChatBubble(
      type: ChatBubbleType.other,
      avatarName: avatarName,
      time: time,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 230,
          decoration: BoxDecoration(
            color: MlsColors.bgCardPrimary,
            borderRadius: MlsRadius.card,
            border: Border.all(color: MlsColors.borderLight, width: 0.5),
            boxShadow: MlsShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 92,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                    begin: Alignment(-0.7, -1),
                    end: Alignment(0.7, 1),
                    colors: [Color(0xFFE8EDF5), Color(0xFFDCE3EE)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.image, size: 32, color: Color(0x3D0F172A)),
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listingName,
                      style: TextStyle(
                        fontFamilyFallback: MlsTypography.sansFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MlsColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          priceWan,
                          style: TextStyle(
                            fontFamily: MlsTypography.monoFamily,
                            fontFamilyFallback: MlsTypography.monoFallback,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: MlsColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '万',
                          style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MlsColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${areaSqm}㎡',
                          style: MlsTypography.caption1,
                        ),
                      ],
                    ),
                    if (tags != null && tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags.take(3).map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: MlsColors.bgPageStart,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t, style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 10,
                            color: MlsColors.textSecondary,
                          )),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 带看邀请行动卡（我方发送，深色）
  factory MlsChatBubble.showingInvite({
    required bool accepted,
    required VoidCallback onAccept,
    required VoidCallback onReschedule,
    required String time,
  }) {
    return MlsChatBubble(
      type: ChatBubbleType.mine,
      time: time,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: MlsColors.panelDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, size: 16, color: const Color(0xFF86EFAC)),
                const SizedBox(width: 6),
                Text(
                  '带看邀请',
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '邀请你一起带客户实地看房',
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 12,
                color: MlsColors.textOnDarkSubtle,
              ),
            ),
            if (accepted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1A22C55E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x4D22C55E), width: 0.5),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: const Color(0xFF86EFAC)),
                    const SizedBox(width: 6),
                    Text(
                      '已同意 · 留痕已记录',
                      style: TextStyle(
                        fontFamilyFallback: MlsTypography.sansFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF86EFAC),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Container(height: 0.5, color: MlsColors.borderOnDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onAccept,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: MlsColors.buttonBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '同意带看',
                          style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: onReschedule,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MlsColors.borderOnDark, width: 0.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '改时间',
                          style: TextStyle(
                            fontFamilyFallback: MlsTypography.sansFallback,
                            fontSize: 12,
                            color: MlsColors.textOnDarkSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 系统事件
  factory MlsChatBubble.system({
    required IconData icon,
    required String text,
    bool secured = false,
  }) {
    return MlsChatBubble(
      type: ChatBubbleType.system,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: secured ? const Color(0x1A22C55E) : const Color(0x0A0F172A),
          borderRadius: BorderRadius.circular(16),
          border: secured ? Border.all(color: const Color(0x4D22C55E), width: 0.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: secured ? const Color(0xFF86EFAC) : MlsColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 11,
                color: secured ? const Color(0xFF86EFAC) : MlsColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (type == ChatBubbleType.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Center(child: child),
      );
    }

    final isMine = type == ChatBubbleType.mine;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isMine
          ? BoxDecoration(
              gradient: MlsColors.buttonBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: MlsShadows.primaryButton,
            )
          : BoxDecoration(
              color: MlsColors.bgCardPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: MlsColors.borderLight, width: 0.5),
              boxShadow: MlsShadows.sm,
            ),
      child: child ??
          Text(
            text ?? '',
            style: TextStyle(
              fontFamilyFallback: MlsTypography.sansFallback,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: isMine ? Colors.white : MlsColors.textPrimary,
              height: 1.5,
            ),
          ),
    );

    final timeWidget = time != null
        ? Padding(
            padding: EdgeInsets.only(top: 4, left: isMine ? 0 : 40),
            child: Text(
              time!,
              style: TextStyle(
                fontFamily: MlsTypography.monoFamily,
                fontFamilyFallback: MlsTypography.monoFallback,
                fontSize: 9.5,
                color: MlsColors.textTertiary,
              ),
              textAlign: isMine ? TextAlign.right : TextAlign.left,
            ),
          )
        : null;

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            if (timeWidget != null) timeWidget,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatarName != null)
            MlsAvatar(name: avatarName!, size: 28),
          if (avatarName != null) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bubble,
                if (timeWidget != null) timeWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
