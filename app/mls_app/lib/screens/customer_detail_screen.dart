import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/customer_service.dart';

/// 客户详情页 · Day 12
///
/// 顶部:基础信息 + 操作按钮(编辑 / 结单)
/// 中部:统计 · 时间线(申请/带看/成交事件混排)
/// 底部:跟进记录区(显示 + 添加)
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _dirty = false; // 有任何修改时标记,pop 时 return true

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return CustomerService.instance.timeline(widget.customerId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  // ========== 操作 ==========

  Future<void> _addMemo() async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddMemoDialog(),
    );
    if (text == null || text.trim().isEmpty) return;

    try {
      await CustomerService.instance.addMemo(widget.customerId, text.trim());
      _dirty = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加跟进记录')),
      );
      _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('添加失败:$msg')));
    }
  }

  Future<void> _closeCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标记为已结单?'),
        content: const Text(
          '标记后,此客户将在列表中显示为已结单状态(灰色)。\n'
          '你可以随时通过编辑恢复为活跃。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await CustomerService.instance.close(widget.customerId);
      _dirty = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已标记为已结单')),
      );
      _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // 回退时,如果有过修改,通知列表页刷新
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_dirty),
          ),
          title: const Text('客户详情'),
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
            final customer = Map<String, dynamic>.from(data['customer']);
            final events =
                (data['events'] as List).cast<Map<String, dynamic>>();
            final stats = Map<String, dynamic>.from(data['stats']);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(customer),
                  const SizedBox(height: 16),
                  _buildStats(stats),
                  const SizedBox(height: 16),
                  _buildTimeline(events),
                  const SizedBox(height: 16),
                  _buildMemos(customer),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ========== 顶部基础信息 ==========

  Widget _buildHeader(Map<String, dynamic> c) {
    final surname = (c['surname'] ?? '') as String;
    final gender = (c['gender'] ?? '') as String;
    final phone = (c['phone'] ?? '') as String;
    final requirements = (c['requirements'] ?? '') as String;
    final status = (c['status'] ?? 'active') as String;
    final isClosed = status == 'closed';
    final avatarColor = gender == 'male' ? Colors.blue : Colors.pink;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isClosed
                      ? Colors.grey.withValues(alpha: 0.3)
                      : avatarColor.withValues(alpha: 0.15),
                  child: Icon(
                    gender == 'male' ? Icons.person : Icons.person_2,
                    color: isClosed ? Colors.grey : avatarColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$surname${gender == 'male' ? '先生' : '女士'}',
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (isClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: const Text('已结单',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11.0)),
                            ),
                        ],
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(phone,
                                style: const TextStyle(
                                    fontSize: 12.0, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isClosed)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: '更多操作',
                    onPressed: () => _showMenu(),
                  ),
              ],
            ),
            if (requirements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        requirements,
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: Colors.orange),
              title: const Text('标记为已结单'),
              onTap: () {
                Navigator.of(ctx).pop();
                _closeCustomer();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 统计区 ==========

  Widget _buildStats(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _statBox(
            icon: Icons.description_outlined,
            color: MlsColors.primary,
            label: '申请',
            count: (stats['requests_count'] ?? 0) as int,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statBox(
            icon: Icons.camera_alt_outlined,
            color: MlsColors.warning,
            label: '带看',
            count: (stats['showings_count'] ?? 0) as int,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statBox(
            icon: Icons.gavel_outlined,
            color: MlsColors.success,
            label: '成交',
            count: (stats['transactions_count'] ?? 0) as int,
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(color: color, fontSize: 11.0)),
        ],
      ),
    );
  }

  // ========== 时间线 ==========

  Widget _buildTimeline(List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('时间线',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            child: const Text('还没有协作事件',
                style: TextStyle(color: Colors.grey, fontSize: 12.0)),
          )
        else
          ...events.map((e) => _timelineRow(e)),
      ],
    );
  }

  Widget _timelineRow(Map<String, dynamic> event) {
    final type = event['type'] as String;
    final snap = Map<String, dynamic>.from(event['listing_snapshot'] ?? {});
    final community = (snap['community'] ?? '') as String;
    final status = (event['status'] ?? '') as String;
    final time = event['time'] as String?;

    IconData icon;
    Color color;
    String label;

    switch (type) {
      case 'request':
        icon = Icons.description_outlined;
        color = Colors.blue;
        label = _requestStatusText(status);
        break;
      case 'showing':
        icon = Icons.camera_alt_outlined;
        color = Colors.orange;
        label = _showingStatusText(status);
        break;
      case 'transaction':
        icon = Icons.gavel_outlined;
        color = Colors.green;
        label = _txStatusText(status);
        break;
      default:
        icon = Icons.circle_outlined;
        color = Colors.grey;
        label = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community.isEmpty ? '(未知房源)' : community,
                  style: const TextStyle(
                      fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(color: color, fontSize: 11.0)),
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Text(_formatTime(time),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11.0)),
                ],
                // 带看事件额外显示备忘
                if (type == 'showing' &&
                    (event['customer_feedback'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      '备忘:${event['customer_feedback']}',
                      style: const TextStyle(fontSize: 11.0),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _requestStatusText(String s) {
    switch (s) {
      case 'pending':
        return '带客申请 · 待审批';
      case 'approved':
        return '带客申请 · 已通过';
      case 'auto_approved':
        return '带客申请 · 直接带看';
      case 'rejected':
        return '带客申请 · 已拒绝';
      case 'expired':
        return '带客申请 · 已过期';
      default:
        return '带客申请 · $s';
    }
  }

  String _showingStatusText(String s) {
    switch (s) {
      case 'pending_confirm':
        return '带看记录 · 待 LA 确认';
      case 'confirmed':
        return '带看已确认';
      case 'rejected':
        return '带看已驳回';
      default:
        return '带看 · $s';
    }
  }

  String _txStatusText(String s) {
    switch (s) {
      case 'pending_la_confirm':
        return '成交待 LA 确认';
      case 'confirmed':
        return '成交已生效';
      case 'rejected':
        return '成交已驳回';
      case 'cancelled':
        return '成交已撤回';
      default:
        return '成交 · $s';
    }
  }

  String _formatTime(String iso) {
    try {
      final t = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
    } catch (_) {
      return iso;
    }
  }

  // ========== 跟进记录 ==========

  Widget _buildMemos(Map<String, dynamic> c) {
    final memos = (c['memo_entries'] as List?)?.cast<dynamic>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('跟进记录',
                style: TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('(${memos.length})',
                style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addMemo,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (memos.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: const Text(
              '点击右上角「添加」记录每次跟进',
              style: TextStyle(color: Colors.grey, fontSize: 11.0),
            ),
          )
        else
          ...memos.reversed.map((m) {
            final map = Map<String, dynamic>.from(m as Map);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((map['text'] ?? '') as String,
                      style: const TextStyle(fontSize: 12.0)),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime((map['created_at'] ?? '') as String),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11.0),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ========== 错误态 ==========

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

// ========== 添加备忘 Dialog ==========

class _AddMemoDialog extends StatefulWidget {
  const _AddMemoDialog();

  @override
  State<_AddMemoDialog> createState() => _AddMemoDialogState();
}

class _AddMemoDialogState extends State<_AddMemoDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加跟进记录'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: '如:电话沟通,客户强调学区...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}