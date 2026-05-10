import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../services/settlement_service.dart';

/// 待我操作的奖金结算单列表
///
/// 后端合并返两类:
///   - viewer_role='la' + status='pending_payment' → 我(LA)要付款给对方
///   - viewer_role='ba' + status='pending_receipt' → 对方(LA)已付款,我(BA)待确认
///
/// 本 MVP 前端只用第一类(LA 待付),第二类卡片展示但按钮提示"等后续版本"。
/// BA 确认收款需带证据上传,等 B 对象存储迁完后补。
class SettlementPendingScreen extends StatefulWidget {
  const SettlementPendingScreen({super.key});

  @override
  State<SettlementPendingScreen> createState() =>
      _SettlementPendingScreenState();
}

class _SettlementPendingScreenState extends State<SettlementPendingScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = SettlementService.instance.listPendingMy();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待我操作的奖金'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _buildError(snap.error.toString());
          }
          final data = snap.data!;
          final items = (data['items'] as List).cast<Map<String, dynamic>>();
          if (items.isEmpty) {
            return _buildEmpty();
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _SettlementCard(
                item: items[i],
                onTap: () async {
                  final changed = await context.push<bool>(
                      '/settlements/${items[i]['settlement_id']}');
                  if (changed == true) _reload();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无待操作的奖金单',
              style: TextStyle(color: Colors.grey, fontSize: AppTheme.fontSectionTitle)),
          SizedBox(height: 6),
          Text('成交确认通过且有奖金的交易会自动生成结算单',
              style: TextStyle(color: Colors.grey, fontSize: AppTheme.fontCaption)),
        ],
      ),
    );
  }

  Widget _buildError(String err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败:$err', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reload, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _SettlementCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sp = Map<String, dynamic>.from(item['listing_snapshot'] ?? {});
    final role = item['viewer_role'] as String? ?? '';
    final status = item['status'] as String? ?? '';
    final bonus = (item['bonus_yuan'] as num?)?.toInt() ?? 0;
    final dealPrice = (item['deal_price_yuan'] as num?)?.toInt() ?? 0;
    final counterpart = item['counterpart_name'] ?? '-';

    final isLaPending = role == 'la' && status == 'pending_payment';
    final isBaPending = role == 'ba' && status == 'pending_receipt';

    Color tagColor;
    String tagText;
    String actionHint;
    if (isLaPending) {
      tagColor = Colors.orange;
      tagText = '待我付款';
      actionHint = '点击标记已付款';
    } else if (isBaPending) {
      tagColor = Colors.blue;
      tagText = '待我确认收款';
      actionHint = '(收款确认功能即将开放)';
    } else {
      tagColor = Colors.grey;
      tagText = status;
      actionHint = '';
    }

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(tagText,
                        style: TextStyle(
                            color: tagColor,
                            fontSize: AppTheme.fontCaption,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: AppTheme.grey400, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${sp['community'] ?? '-'} ${sp['building'] ?? ''}号楼'
                '${sp['unit'] ?? ''}单元${sp['room_no'] ?? ''}',
                style: const TextStyle(
                    fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '成交价 ¥${(dealPrice / 10000).toStringAsFixed(1)} 万'
                ' · 对方:$counterpart',
                style: const TextStyle(color: Colors.grey, fontSize: AppTheme.fontCaption),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('奖金 ',
                      style: TextStyle(fontSize: AppTheme.fontCaption, color: Colors.grey)),
                  Text('¥$bonus',
                      style: TextStyle(
                          fontSize: AppTheme.fontAppBar,
                          fontWeight: FontWeight.bold,
                          color: tagColor)),
                  const SizedBox(width: 4),
                  const Text('元',
                      style: TextStyle(fontSize: AppTheme.fontCaption, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text('≈ ${(bonus / 10000).toStringAsFixed(2)} 万',
                      style: const TextStyle(
                          fontSize: AppTheme.fontCaption, color: Colors.grey)),
                ],
              ),
              if (actionHint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(actionHint,
                    style: TextStyle(
                        fontSize: AppTheme.fontCaption, color: tagColor.withValues(alpha: 0.9))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}