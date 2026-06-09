import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_chat_bubble.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_status_badge.dart';
import '../theme/mls_shadows.dart';

/// 消息
class ChatMessage {
  final String id;
  final ChatBubbleType type;
  final String? text;
  final String? time;
  final String? avatarName;
  final Widget? child;
  final bool isDateSep;

  const ChatMessage({
    required this.id,
    this.type = ChatBubbleType.other,
    this.text,
    this.time,
    this.avatarName,
    this.child,
    this.isDateSep = false,
  });
}

/// 协作会话 IM
class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String? listingName;

  const ChatScreen({
    super.key,
    required this.partnerName,
    this.listingName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _msgs = [];
  bool _typing = false;
  bool _accepted = false;
  int _msgId = 0;

  @override
  void initState() {
    super.initState();
    _seedMessages();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _seedMessages() {
    final now = DateTime.now();
    final t = (int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    _msgs.addAll([
      ChatMessage(id: 'd1', isDateSep: true, text: 'TODAY · ${now.month}月${now.day}日'),
      ChatMessage(id: 's1', type: ChatBubbleType.system, child: MlsChatBubble.system(icon: Icons.handshake, text: '${widget.partnerName} 发起了带看申请', secured: true).child),
      ChatMessage(id: 'o1', type: ChatBubbleType.other, text: '你好，我这边有一位客户对「${widget.listingName ?? "万达华府"}」有兴趣', time: t(9, 30), avatarName: widget.partnerName),
      ChatMessage(id: 'm1', type: ChatBubbleType.mine, text: '好的，房子随时可看，有钥匙', time: t(9, 32)),
      ChatMessage(id: 'o2', type: ChatBubbleType.other, text: '客户想了解下户型和装修情况', time: t(9, 35), avatarName: widget.partnerName),
      ChatMessage(id: 'm2', type: ChatBubbleType.mine, child: MlsChatBubble.showingInvite(accepted: _accepted, onAccept: () => setState(() => _accepted = true), onReschedule: () {}, time: t(9, 38)).child, time: t(9, 38)),
    ]);
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _msgs.add(ChatMessage(id: 'm${_msgId++}', type: ChatBubbleType.mine, text: text, time: time));
      _textCtrl.clear();
      _typing = true;
    });
    _scrollToBottom();
    // 自动回复
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(ChatMessage(
          id: 'o${_msgId++}',
          type: ChatBubbleType.other,
          text: '好的，收到👍',
          time: '${now.hour.toString().padLeft(2, '0')}:${(now.minute + 1).clamp(0, 59).toString().padLeft(2, '0')}',
          avatarName: widget.partnerName,
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: SafeArea(
        child: Column(children: [
          MlsNavBar(
            title: widget.partnerName,
            sub: 'ONLINE · 在线',
            right: GestureDetector(
              onTap: () => context.push('/trace', extra: {
                'listingName': widget.listingName ?? '', 'partnerName': widget.partnerName,
                'partnerRole': 'BA', 'customerName': '', 'currentStep': 3, 'laName': '张三',
              }),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.clipboardCheck, size: 16, color: MlsColors.primary),
                const SizedBox(width: 4),
                Text('留痕', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 12, fontWeight: FontWeight.w600, color: MlsColors.primary)),
                const SizedBox(width: 8),
              ]),
            ),
          ),
          // 伙伴子栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MlsColors.borderLight, width: 0.5))),
            child: Row(children: [
              MlsAvatar(name: widget.partnerName, size: 30, onlineStatus: MlsOnlineStatus.online),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(widget.partnerName, style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 13, fontWeight: FontWeight.w600, color: MlsColors.textPrimary)),
                    const SizedBox(width: 6),
                    MlsStatusBadge(text: 'BA', variant: MlsBadgeVariant.info, size: MlsBadgeSize.dense, mono: true),
                  ]),
                  Text('协作中 · ${widget.listingName ?? "房源"}', style: MlsTypography.caption1),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x1A22C55E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x4D22C55E), width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: MlsColors.online)),
                  const SizedBox(width: 5),
                  Text('协作进行中', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 10, color: const Color(0xFF86EFAC))),
                ]),
              ),
            ]),
          ),
          // 消息流
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _msgs.length + (_typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (_typing && i == _msgs.length) {
                  return _buildTypingIndicator();
                }
                final m = _msgs[i];
                if (m.isDateSep) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0x0A0F172A), borderRadius: BorderRadius.circular(12)),
                        child: Text(m.text!, style: TextStyle(fontFamily: MlsTypography.monoFamily, fontFamilyFallback: MlsTypography.monoFallback, fontSize: 10, letterSpacing: 1, color: MlsColors.textTertiary)),
                      ),
                    ),
                  );
                }
                return MlsChatBubble(type: m.type, text: m.text, time: m.time, avatarName: m.avatarName, child: m.child);
              },
            ),
          ),
          // 快捷栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              _quickChip(LucideIcons.calendar, '发起带看', () {}),
              const SizedBox(width: 6),
              _quickChip(LucideIcons.home, '发房源', () {}),
              const SizedBox(width: 6),
              _quickChip(LucideIcons.clipboardCheck, '看留痕', () => context.push('/trace', extra: {
                'listingName': widget.listingName ?? '', 'partnerName': widget.partnerName,
                'partnerRole': 'BA', 'customerName': '', 'currentStep': 3, 'laName': '张三',
              })),
            ]),
          ),
          // 输入栏
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(color: MlsColors.bgPageEnd.withValues(alpha: 0.88), border: const Border(top: BorderSide(color: MlsColors.borderLight, width: 0.5))),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: MlsColors.bgCardPrimary, borderRadius: BorderRadius.circular(24), border: Border.all(color: MlsColors.borderStrong, width: 0.5)),
                    child: TextField(
                      controller: _textCtrl,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 14, color: MlsColors.textPrimary),
                      decoration: const InputDecoration(hintText: '输入消息...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: hasText ? _send : null,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasText ? MlsColors.buttonBlue : null,
                      color: hasText ? null : const Color(0x0D0F172A),
                      boxShadow: hasText ? MlsShadows.primaryButton : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.send, size: 18, color: hasText ? Colors.white : MlsColors.textTertiary),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _quickChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: MlsColors.primaryBg, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: MlsColors.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: MlsColors.primary)),
        ]),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MlsAvatar(name: widget.partnerName, size: 28),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: MlsColors.bgCardPrimary, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)), border: Border.all(color: MlsColors.borderLight, width: 0.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _typingDot(0), const SizedBox(width: 5), _typingDot(1), const SizedBox(width: 5), _typingDot(2),
          ]),
        ),
      ]),
    );
  }

  Widget _typingDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: const Interval(0, 0.66, curve: Curves.easeInOut),
      builder: (_, v, __) => Opacity(opacity: v, child: Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: MlsColors.textTertiary))),
    );
  }
}
