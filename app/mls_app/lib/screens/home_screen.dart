import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../services/dashboard_service.dart';

/// 登录后的工作台
/// Day 9 重构:废掉"快捷入口"区,所有入口整合为 7 张卡
/// 卡 2 "共享房源库"显示"总 X · 今 Y",点进去默认全部
class HomeScreen extends StatefulWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storage = FlutterSecureStorage();

  late Future<Map<String, dynamic>> _meFuture;
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _meFuture = _fetchMe();
    _summaryFuture = DashboardService.instance.summary();
  }

  Future<Map<String, dynamic>> _fetchMe() async {
    final response = await ApiClient.instance.dio.get('/me');
    return response.data as Map<String, dynamic>;
  }

  Future<void> _refreshAll() async {
    final newSummary = DashboardService.instance.summary();
    setState(() {
      _summaryFuture = newSummary;
    });
    await newSummary;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'agent_id');
    await _storage.delete(key: 'name');

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工作台'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              setState(() {
                _meFuture = _fetchMe();
                _summaryFuture = DashboardService.instance.summary();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _meFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      '加载失败:${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _meFuture = _fetchMe();
                        });
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            final me = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // 顶部问候
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.waving_hand,
                          size: 28, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '早上好,${me['name']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _roleTag(me['role'], me['status']),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 7 卡仪表盘(4 行:2+2+2+1)
                _buildSummaryDashboard(),
                const SizedBox(height: 20),

                Center(
                  child: Text(
                    '手机号 ${me['phone'] ?? '-'} · ${me['store_name'] ?? '独立经纪人'}',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 7 卡仪表盘
  Widget _buildSummaryDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snap) {
        int myOnSale = 0;
        int sharedTotal = 0;
        int sharedNewToday = 0;
        int mySentRecentChanges = 0;
        int pendingApproval = 0;
        int pendingConfirmShowing = 0;
        int pendingConfirmTransaction = 0;
        int pendingSettlement = 0;

        final loading = snap.connectionState == ConnectionState.waiting;
        final err = snap.hasError;

        if (snap.hasData && snap.data!['my_on_sale_count'] != null) {
          final d = snap.data!;
          myOnSale = (d['my_on_sale_count'] as num?)?.toInt() ?? 0;
          sharedTotal = (d['shared_total_count'] as num?)?.toInt() ?? 0;
          sharedNewToday =
              (d['shared_new_today_count'] as num?)?.toInt() ?? 0;
          mySentRecentChanges =
              (d['my_sent_recent_changes_count'] as num?)?.toInt() ?? 0;
          pendingApproval =
              (d['pending_approval_count'] as num?)?.toInt() ?? 0;
          pendingConfirmShowing =
              (d['pending_confirm_showing_count'] as num?)?.toInt() ?? 0;
          pendingConfirmTransaction =
              (d['pending_confirm_transaction_count'] as num?)?.toInt() ?? 0;
          pendingSettlement =
              (d['pending_settlement_count'] as num?)?.toInt() ?? 0;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  const Text(
                    '待处理 & 数据概览',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (loading)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  if (err)
                    const Icon(Icons.cloud_off,
                        size: 13, color: Colors.redAccent),
                ],
              ),
            ),
            // 第 1 行:房源数据概览
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.home_outlined,
                    label: '我在售房源',
                    count: myOnSale,
                    color: Colors.blue,
                    badge: false,
                    onTap: () async {
                      await context.push('/listings/mine');
                      _refreshAll();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.share_outlined,
                    label: '共享房源库',
                    count: sharedTotal,
                    subText: sharedNewToday > 0 ? '今日新 $sharedNewToday' : null,
                    color: Colors.teal,
                    badge: false,
                    onTap: () async {
                      await context.push('/listings/shared');
                      _refreshAll();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 第 2 行:申请双向(都有 badge)
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.send_outlined,
                    label: '我发出的申请',
                    count: mySentRecentChanges,
                    color: Colors.indigo,
                    badge: true,
                    onTap: () async {
                      await context.push('/showing-requests/sent');
                      _refreshAll();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.inbox_outlined,
                    label: '收到的申请',
                    count: pendingApproval,
                    color: Colors.orange,
                    badge: true,
                    onTap: () async {
                      await context.push('/showing-requests/received');
                      _refreshAll();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 第 3 行:确认类
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.fact_check_outlined,
                    label: '待我确认带看',
                    count: pendingConfirmShowing,
                    color: Colors.deepPurple,
                    badge: true,
                    onTap: () async {
                      await context.push('/showings/pending-confirm');
                      _refreshAll();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.gavel_outlined,
                    label: '待我确认成交',
                    count: pendingConfirmTransaction,
                    color: Colors.redAccent,
                    badge: true,
                    onTap: () async {
                      await context.push('/transactions/pending-la');
                      _refreshAll();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 第 4 行:奖金(全宽)
            _StatCard(
              icon: Icons.payments_outlined,
              label: '待我操作奖金',
              count: pendingSettlement,
              color: Colors.orange.shade800,
              badge: true,
              fullWidth: true,
              onTap: () async {
                await context.push('/settlements/pending-my');
                _refreshAll();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _roleTag(String? role, String? status) {
    final label = switch (role) {
      'boss' => '老板',
      'agent' => '经纪人',
      'admin' => '管理员',
      _ => role ?? '-',
    };
    final statusLabel = switch (status) {
      'active' => '正常',
      'pending' => '待审核',
      'banned' => '已封禁',
      'deleted' => '已注销',
      _ => status ?? '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label · $statusLabel',
        style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
      ),
    );
  }
}

/// 工作台卡片组件
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool badge;
  final bool fullWidth;
  final String? subText; // 副标题,用于"今日新 X"提示
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.badge,
    required this.onTap,
    this.fullWidth = false,
    this.subText,
  });

  @override
  Widget build(BuildContext context) {
    final hot = badge && count > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: fullWidth ? 72 : 84,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hot
                  ? color.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
              width: hot ? 1.5 : 1,
            ),
          ),
          child: fullWidth
              ? _buildWideLayout(hot)
              : _buildSquareLayout(hot),
        ),
      ),
    );
  }

  Widget _buildSquareLayout(bool hot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: hot ? color : Colors.black87,
              ),
            ),
            if (hot) ...[
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (subText != null) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  subText!,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWideLayout(bool hot) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                hot ? '有新记录待处理,点击查看' : '暂无待处理',
                style: TextStyle(
                  color: hot ? color : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: hot ? color : Colors.black87,
              ),
            ),
            if (hot) ...[
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ],
    );
  }
}