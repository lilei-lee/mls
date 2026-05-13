import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/collaboration_service.dart';
import '../widgets/progress_tracker.dart';

/// 协作列表页 · Day 13 新建
///
/// 顶部 2 Tab:买方协作(BA)/ 卖方协作(LA)
/// 每条用进度条卡片展示协作的完整生命周期
class CollaborationListScreen extends StatefulWidget {
  const CollaborationListScreen({super.key});

  @override
  State<CollaborationListScreen> createState() =>
      _CollaborationListScreenState();
}

class _CollaborationListScreenState extends State<CollaborationListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _buyerFuture;
  late Future<Map<String, dynamic>> _sellerFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _refresh();
      }
    });
    _buyerFuture = _load('buyer');
    _sellerFuture = _load('seller');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load(String role) {
    return CollaborationService.instance.listMine(role);
  }

  void _refresh() {
    setState(() {
      _buyerFuture = _load('buyer');
      _sellerFuture = _load('seller');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('协作'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: '买方协作'),
            Tab(text: '卖方协作'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_buyerFuture, role: 'buyer'),
          _buildList(_sellerFuture, role: 'seller'),
        ],
      ),
      floatingActionButton: const SizedBox.shrink(),
    );
  }

  Widget _buildList(Future<Map<String, dynamic>> future,
      {required String role}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _buildError(snap.error.toString());
        }

        final items =
            (snap.data!['items'] as List).cast<Map<String, dynamic>>();

        if (items.isEmpty) {
          return _buildEmpty(role);
        }

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length + 1,
            itemBuilder: (ctx, idx) {
              if (idx == 0) {
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                  child: Text(
                    '共 ${items.length} 条协作',
                    style: const TextStyle(color: Colors.grey, fontSize: 12.0),
                  ),
                );
              }
              return _CollaborationCard(
                data: items[idx - 1],
                onTap: () => _onTap(items[idx - 1]),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onTap(Map<String, dynamic> data) async {
    // 根据当前阶段决定跳转哪个详情页
    final stage = data['stage'] as int;
    final settlementId = data['settlement_id'] as String?;
    final transactionId = data['transaction_id'] as String?;
    final requestId = data['request_id'] as String?;

    // 优先级:有结算 → 结算详情;有成交 → 成交详情(cancelled 除外);否则 → 申请详情
    final txStatus = data['transaction_status'] as String?;
    if (stage >= 4 && settlementId != null) {
      await context.push('/settlements/$settlementId');
    } else if (stage >= 3 && transactionId != null) {
      if (txStatus == 'cancelled') {
        // cancelled 的 transaction 详情页无操作按钮(SizedBox.shrink),
        // 跳到申请详情页找"重新发起成交确认"入口
        await context.push('/showing-request/$requestId');
      } else {
        // pending_la_confirm / rejected / confirmed 直跳成交详情
        await context.push('/transaction/$transactionId');
      }
    } else if (requestId != null) {
      await context.push('/showing-request/$requestId');
    }
    // 详情页 pop 回来自动刷新列表(防止 LA 通过/驳回后 BA 端列表数据陈旧)
    if (mounted) _refresh();
  }

  Widget _buildEmpty(String role) {
    final tip = role == 'buyer' ? '还没有带客户的协作' : '还没有同行带客户来你的房源';
    final hint = role == 'buyer'
        ? '去刷一下共享房源库,看看有没有合适客户的房'
        : '同行看到你的房源后,会发起带客申请';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            role == 'buyer'
                ? Icons.luggage_outlined
                : Icons.storefront_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(tip,
              style: const TextStyle(color: Colors.grey, fontSize: 16.0)),
          const SizedBox(height: 6),
          Text(hint,
              style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
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
          Text('加载失败:$err',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('重试')),
        ],
      ),
    );
  }
}

// ============= 子组件:协作卡片 =============

class _CollaborationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CollaborationCard({required this.data, required this.onTap});

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final t = DateTime.parse(iso);
      final diff = DateTime.now().difference(t);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
      if (diff.inHours < 24) return '${diff.inHours} 小时前';
      if (diff.inDays < 30) return '${diff.inDays} 天前';
      return '${(diff.inDays / 30).floor()} 个月前';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = Map<String, dynamic>.from(data['listing_snapshot']);
    final community = (snapshot['community'] ?? '') as String;
    final building = (snapshot['building'] ?? '') as String;
    final unit = (snapshot['unit'] ?? '') as String;
    final roomNo = (snapshot['room_no'] ?? '') as String;

    final counterparty = (data['counterparty_name'] ?? '') as String;
    final customerSurname = (data['customer_surname'] ?? '') as String;
    final customerGender = (data['customer_gender'] ?? '') as String;

    final stage = data['stage'] as int;
    final stageStatus = (data['stage_status'] ?? '') as String;
    final stageLabel = (data['stage_label'] ?? '') as String;
    final isFailed = (data['is_failed'] ?? false) as bool;

    final lastActionText = (data['last_action_text'] ?? '') as String;
    final lastActionTime = data['last_action_time'] as String?;

    final role = data['role'] as String;
    final counterpartyLabel = role == 'buyer' ? '挂牌:' : '带客:';

    Color stageColor() {
      if (isFailed) return Colors.red;
      if (stageStatus == 'expired') return Colors.grey;
      if (stage == 5 && stageStatus == 'done') return Colors.green;
      return Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部:房源 + 状态徽章
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.home_work_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$community $building-$unit-$roomNo',
                      style: const TextStyle(
                          fontSize: 12.0, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stageColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      stageLabel,
                      style: TextStyle(
                          color: stageColor(),
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 客户 + 对方信息
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        '客户:$customerSurname${customerGender == 'male' ? '先生' : '女士'}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11.0),
                      ),
                    ],
                  ),
                  if (counterparty.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.handshake_outlined,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          '$counterpartyLabel$counterparty',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11.0),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 进度条
              ProgressTracker(
                stage: stage,
                stageStatus: stageStatus,
                isFailed: isFailed,
              ),
              const SizedBox(height: 10),
              // 底部:最近动作
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 11, color: MlsColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      lastActionText,
                      style: TextStyle(
                          color: MlsColors.textPrimary, fontSize: 11.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _relativeTime(lastActionTime),
                    style: TextStyle(
                        color: MlsColors.textSecondary, fontSize: 11.0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}