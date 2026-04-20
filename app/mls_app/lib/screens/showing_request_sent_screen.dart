import 'package:flutter/material.dart';
import '../models/showing_request.dart';
import '../services/showing_request_service.dart';
import 'package:go_router/go_router.dart';

/// BA 视角:我发出的带客申请列表
class ShowingRequestSentScreen extends StatefulWidget {
  const ShowingRequestSentScreen({super.key});

  @override
  State<ShowingRequestSentScreen> createState() =>
      _ShowingRequestSentScreenState();
}

class _ShowingRequestSentScreenState extends State<ShowingRequestSentScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShowingRequestService.instance.listSent();
  }

  void _refresh() {
    setState(() {
      _future = ShowingRequestService.instance.listSent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我发出的申请'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败:${snap.error}',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _refresh, child: const Text('重试')),
                ],
              ),
            );
          }

          final items =
              (snap.data!['items'] as List).cast<Map<String, dynamic>>();

          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('还没有发出过申请',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('去共享库挑套房,给房东发申请吧',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (ctx, i) => InkWell(
                onTap: () async {
                  await context.push(
                    '/showing-request/${items[i]['request_id']}',
                  );
                  _refresh();
                },
                child: _SentRequestCard(item: items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _SentRequestCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = ShowingRequestStatus.fromString(item['status']);
    final snapshot = item['listing_snapshot'] as Map<String, dynamic>;
    final counter = item['counterparty'] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部:房源地址 + 状态徽章
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${snapshot['community']} ${snapshot['building']}号楼${snapshot['unit']}单元${snapshot['room_no']}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${snapshot['layout']} · ${snapshot['area_sqm']}㎡ · ¥${snapshot['price_wan']}万',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 20),

            // 客户信息
            Text(
              '客户:${item['customer_surname']}${item['customer_gender'] == 'male' ? '先生' : '女士'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '需求:${item['requirements']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // 根据状态显示对方身份 / 拒绝理由
            if (status == ShowingRequestStatus.approved) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '房东:${counter['name']} · ${counter['phone']}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status == ShowingRequestStatus.rejected) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '拒绝理由:${item['reject_reason_text'] ?? ''}${item['reject_extra'] != null ? '(${item['reject_extra']})' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('等待房东审批...',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ShowingRequestStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    switch (status) {
      case ShowingRequestStatus.pending:
        color = Colors.orange;
        break;
      case ShowingRequestStatus.approved:
        color = Colors.green;
        break;
      case ShowingRequestStatus.rejected:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}