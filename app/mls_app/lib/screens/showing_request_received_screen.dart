import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/showing_request.dart';
import '../services/showing_request_service.dart';

/// LA 视角:我收到的带客申请(别人向我房源申请)
class ShowingRequestReceivedScreen extends StatefulWidget {
  const ShowingRequestReceivedScreen({super.key});

  @override
  State<ShowingRequestReceivedScreen> createState() =>
      _ShowingRequestReceivedScreenState();
}

class _ShowingRequestReceivedScreenState
    extends State<ShowingRequestReceivedScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _future;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _future = ShowingRequestService.instance.listReceived();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = ShowingRequestService.instance.listReceived();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我收到的申请'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '待审批'),
            Tab(text: '已通过'),
            Tab(text: '已拒绝'),
          ],
        ),
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

          final allItems =
              (snap.data!['items'] as List).cast<Map<String, dynamic>>();

          // 按 Tab 过滤
          final targetStatus = switch (_tabController.index) {
            0 => 'pending',
            1 => 'approved',
            2 => 'rejected',
            _ => 'pending',
          };
          final items = allItems
              .where((e) => e['status'] == targetStatus)
              .toList();

          if (items.isEmpty) {
            return _buildEmpty(targetStatus);
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _ReceivedRequestCard(
                item: items[i],
                onTap: () async {
                  await context.push(
                    '/showing-request/${items[i]['request_id']}',
                  );
                  _refresh();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(String status) {
    final title = switch (status) {
      'pending' => '暂无待审批申请',
      'approved' => '暂无已通过的申请',
      'rejected' => '暂无已拒绝的申请',
      _ => '暂无申请',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}

class _ReceivedRequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _ReceivedRequestCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = ShowingRequestStatus.fromString(item['status']);
    final snapshot = Map<String, dynamic>.from(item['listing_snapshot']);
    final counter = Map<String, dynamic>.from(item['counterparty']);
    final approved = status == ShowingRequestStatus.approved;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${snapshot['community']} ${snapshot['building']}-${snapshot['unit']}-${snapshot['room_no']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
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
              if (approved) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '带客人:${counter['name']} · ${counter['store'] ?? ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
      case ShowingRequestStatus.expired:
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