import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/qna_service.dart';
import '../models/qna_thread.dart';

class QnaListScreen extends StatefulWidget {
  final String listingId;
  final String community;
  final bool isOwner;
  final String? highlightId;
  const QnaListScreen({super.key, required this.listingId, this.community = '', this.isOwner = false, this.highlightId});
  @override State<QnaListScreen> createState() => _QnaListScreenState();
}

class _QnaListScreenState extends State<QnaListScreen> {
  late Future<QnaListResp> _future;
  final _scrollCtrl = ScrollController();
  int _highlightIdx = -1;

  @override
  void initState() {
    super.initState();
    _future = QnaService.instance.getList(widget.listingId, limit: 50);
  }

  @override void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  void _scrollToHighlight(QnaListResp data) {
    if (widget.highlightId == null) return;
    final idx = data.items.indexWhere((t) => t.threadId == widget.highlightId);
    if (idx >= 0) {
      setState(() => _highlightIdx = idx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(idx * 180.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _highlightIdx = -1); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('「${widget.community}」的全部问答', style: AppTheme.titleM)),
      body: FutureBuilder<QnaListResp>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snap.data;
          if (data == null || data.items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.helpCircle, size: 48, color: AppTheme.n300),
              const SizedBox(height: 16),
              Text('暂无问答', style: AppTheme.titleS.copyWith(color: AppTheme.n700)),
            ]));
          }
          // Trigger scroll after build
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight(data));

          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: data.items.length + 1,
            itemBuilder: (ctx, i) {
              if (i == data.items.length) return const SizedBox(height: 80);
              final t = data.items[i];
              final isHL = i == _highlightIdx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: isHL ? BoxDecoration(color: AppTheme.primary50, borderRadius: BorderRadius.circular(12)) : null,
                padding: EdgeInsets.all(isHL ? 8 : 0),
                child: _buildItem(t),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildItem(QnaThread t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(LucideIcons.user, size: 16, color: AppTheme.n500),
          const SizedBox(width: 4), Text(t.askerName, style: AppTheme.titleS),
          const Spacer(),
          Text(_fmt(t.questionAt), style: AppTheme.caption.copyWith(color: AppTheme.n300)),
        ]),
        const SizedBox(height: 6),
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.n50, borderRadius: BorderRadius.circular(12)),
          child: Text(t.question, style: AppTheme.bodyM)),
        const SizedBox(height: 6),
        if (t.isAnswered)
          Container(width: double.infinity, padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(left: 24),
            decoration: BoxDecoration(color: AppTheme.primary50, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(t.answererName ?? '', style: AppTheme.caption.copyWith(color: AppTheme.primary500)),
                const Spacer(),
                Text(_fmt(t.answeredAt), style: AppTheme.caption.copyWith(fontSize: AppTheme.fontSmall, color: AppTheme.n300)),
              ]),
              const SizedBox(height: 6),
              Text(t.answer ?? '', style: AppTheme.bodyM),
            ]),
          )
        else
          Padding(padding: const EdgeInsets.only(left: 24),
            child: Text('等待回答...', style: AppTheme.bodyS.copyWith(color: AppTheme.n300, fontStyle: FontStyle.italic))),
        const Divider(height: 24),
      ]),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}天前';
    if (d.inHours > 0) return '${d.inHours}小时前';
    if (d.inMinutes > 0) return '${d.inMinutes}分钟前';
    return '刚刚';
  }
}
