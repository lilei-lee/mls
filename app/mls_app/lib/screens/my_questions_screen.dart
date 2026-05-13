import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../theme/mls_typography.dart';
import '../theme/mls_colors.dart';
import '../services/qna_service.dart';
import '../models/qna_thread.dart';
import '../components/app_card.dart';
import '../components/app_empty.dart';
import '../widgets/base64_image.dart';

/// BA 视角:"我的提问"汇总页
class MyQuestionsScreen extends StatefulWidget {
  const MyQuestionsScreen({super.key});
  @override State<MyQuestionsScreen> createState() => _MyQuestionsScreenState();
}

class _MyQuestionsScreenState extends State<MyQuestionsScreen> {
  late Future<List<QnaThread>> _future;

  @override
  void initState() {
    super.initState();
    _future = QnaService.instance.getMyQuestions();
  }

  void _refresh() => setState(() => _future = QnaService.instance.getMyQuestions());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的提问', style: MlsTypography.sectionTitle)),
      body: FutureBuilder<List<QnaThread>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final threads = snap.data ?? [];
          if (threads.isEmpty) {
            return AppEmpty(icon: LucideIcons.helpCircle, title: '还没有提问', subtitle: '在共享库找到感兴趣的房源,点击 Q&A 区域提问');
          }

          final pending = threads.where((t) => t.status == 'pending').toList();
          final answered = threads.where((t) => t.status == 'answered').toList();

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (pending.isNotEmpty) _buildGroup('等待回答 (${pending.length})', pending, true),
              if (answered.isNotEmpty) _buildGroup('已回答 (${answered.length})', answered, false),
              const SizedBox(height: 80),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildGroup(String title, List<QnaThread> threads, bool isPending) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: MlsTypography.sectionTitle)),
      ...threads.map((t) => _buildCard(t, isPending: isPending)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildCard(QnaThread t, {required bool isPending}) {
    final info = t.listingInfo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard.base(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/listing/${t.listingInfo?.listingId ?? ''}/qna?highlight=${t.threadId}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Listing info row
          if (info != null)
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: SizedBox(width: 40, height: 40,
                    child: info.coverPhoto != null && info.coverPhoto!.isNotEmpty
                        ? Base64Image(dataUrl: info.coverPhoto!, fit: BoxFit.cover)
                        : Container(color: MlsColors.borderLight, child: const Icon(LucideIcons.building, size: 18, color: MlsColors.borderStrong)))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.title, style: MlsTypography.sectionTitle.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(info.communityName, style: MlsTypography.caption1.copyWith(color: MlsColors.textSecondary)),
              ])),
            ]),
          if (info != null) const SizedBox(height: 8),
          // Question
          Text(t.question, style: MlsTypography.body2, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          // Status + time
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: isPending ? MlsColors.warning.withValues(alpha: 0.12) : MlsColors.borderLight, borderRadius: BorderRadius.circular(4)),
              child: Text(isPending ? '等待回答' : '已回答', style: MlsTypography.caption1.copyWith(fontSize: 10, color: isPending ? MlsColors.warning : MlsColors.textSecondary))),
            const Spacer(),
            Text(_fmt(t.questionAt), style: MlsTypography.caption1.copyWith(fontSize: 10, color: MlsColors.borderStrong)),
          ]),
        ]),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}天前';
    if (d.inHours > 0) return '${d.inHours}小时前';
    if (d.inMinutes > 0) return '${d.inMinutes}分钟前';
    return '刚刚';
  }
}
