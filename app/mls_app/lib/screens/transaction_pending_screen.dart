import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/transaction_service.dart';

/// 成交待办列表 — filter=la(默认)=LA视角待确认 / filter=ba=BA视角等待LA
class TransactionPendingScreen extends StatefulWidget {
  final String filter;
  const TransactionPendingScreen({super.key, this.filter = 'la'});

  @override
  State<TransactionPendingScreen> createState() => _TransactionPendingScreenState();
}

class _TransactionPendingScreenState extends State<TransactionPendingScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.filter == 'ba'
        ? TransactionService.instance.listPendingBa()
        : TransactionService.instance.listPending();
  }

  void _reload() {
    setState(() {
      _future = widget.filter == 'ba'
          ? TransactionService.instance.listPendingBa()
          : TransactionService.instance.listPending();
    });
  }

  bool get _isLa => widget.filter != 'ba';

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLa ? '待确认成交' : '等待 LA 确认'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: RefreshIndicator(
        onRefresh: () async { _reload(); await _future; },
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _buildError(snap.error.toString());
            final items = (snap.data!['items'] as List).cast<Map<String, dynamic>>();
            if (items.isEmpty) return _buildEmpty();
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _isLa ? _buildLaCard(items[i]) : _buildBaCard(items[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() => ListView(children: [
    const SizedBox(height: 120),
    const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
    const SizedBox(height: 12),
    Center(child: Text(_isLa ? '暂无待确认的成交记录' : '暂无等待 LA 确认的成交',
        style: const TextStyle(color: Colors.grey, fontSize: 12.0))),
  ]);

  Widget _buildError(String err) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 60, color: Colors.red),
    const SizedBox(height: 16), Text('加载失败:$err', style: const TextStyle(color: Colors.red)),
    const SizedBox(height: 16), ElevatedButton(onPressed: _reload, child: const Text('重试')),
  ]));

  // ── LA 卡片 ──
  Widget _buildLaCard(Map<String, dynamic> it) {
    final sp = Map<String, dynamic>.from(it['listing_snapshot'] ?? {});
    final baPrice = it['ba_deal_price_yuan'] as int?;
    final baWan = (baPrice != null && baPrice > 0) ? (baPrice / 10000).toStringAsFixed(1) : '-';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () async { final r = await context.push<bool>('/transaction/${it['transaction_id']}'); if (r == true) _reload(); },
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: MlsColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4.0)),
              child: const Text('待独立填价', style: TextStyle(color: MlsColors.warning, fontSize: 11.0, fontWeight: FontWeight.bold))),
            const Spacer(),
            Text('BA 已填 $baWan 万', style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
          ]),
          const SizedBox(height: 8),
          Text('${sp['community']} ${sp['building']}-${sp['unit']}-${sp['room_no']}',
              style: const TextStyle(fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · 挂牌 ¥${sp['price_wan']}万',
              style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.person_outline, size: 14, color: Colors.grey), const SizedBox(width: 4),
            Text('BA:${it['ba_agent_name']}', style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
            const Spacer(),
            const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4),
            Text('提交 ${_formatDate(it['ba_submitted_at'] as String?)}', style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
          ]),
        ])),
      ),
    );
  }

  // ── BA 卡片 ──
  Widget _buildBaCard(Map<String, dynamic> it) {
    final sp = Map<String, dynamic>.from(it['listing_snapshot'] ?? {});
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () async { final r = await context.push<bool>('/transaction/${it['transaction_id']}'); if (r == true) _reload(); },
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4.0)),
              child: const Text('等待 LA 确认', style: TextStyle(color: AppTheme.info, fontSize: 11.0, fontWeight: FontWeight.bold))),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          Text('${sp['community']} ${sp['building']}-${sp['unit']}-${sp['room_no']}',
              style: const TextStyle(fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · 挂牌 ¥${sp['price_wan']}万',
              style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.person_outline, size: 14, color: Colors.grey), const SizedBox(width: 4),
            Text('LA:${it['la_agent_name'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
            const Spacer(),
            const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4),
            Text('提交 ${_formatDate(it['ba_submitted_at'] as String?)}', style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
          ]),
        ])),
      ),
    );
  }
}
