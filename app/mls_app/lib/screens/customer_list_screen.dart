import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/customer_service.dart';

/// 客户列表页 · Day 12 新建
///
/// 放在 MainShell 的"客户"Tab 下。
/// - 列表按 updated_at 降序
/// - 顶部右上角 [+] 新建客户
/// - 下拉刷新
/// - 点击客户卡片 → /customer/{id}(详情页)
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return CustomerService.instance.listMine();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _goCreate() async {
    final result = await context.push<bool>('/customer/new');
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _goDetail(String customerId) async {
    final result = await context.push<bool>('/customer/$customerId');
    if (result == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的客户'),
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

          final items =
              (snap.data!['items'] as List).cast<Map<String, dynamic>>();
          if (items.isEmpty) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length + 1,
              itemBuilder: (ctx, idx) {
                if (idx == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '共 ${items.length} 位客户',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  );
                }
                final c = items[idx - 1];
                return _CustomerCard(
                  data: c,
                  onTap: () => _goDetail(c['customer_id'] as String),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreate,
        icon: const Icon(Icons.person_add),
        label: const Text('新建客户'),
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          const Center(
            child: Icon(Icons.people_outline,
                size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '还没有客户',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '点击右上角 [+] 添加第一位客户',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _goCreate,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('新建客户'),
            ),
          ),
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

// ============= 子组件:客户卡片 =============

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CustomerCard({required this.data, required this.onTap});

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
    final surname = (data['surname'] ?? '') as String;
    final gender = (data['gender'] ?? '') as String;
    final phone = (data['phone'] ?? '') as String;
    final requirements = (data['requirements'] ?? '') as String;
    final memoEntries =
        (data['memo_entries'] as List?)?.cast<dynamic>() ?? [];
    final status = (data['status'] ?? 'active') as String;
    final updatedAt = data['updated_at'] as String?;

    final displayName =
        '$surname${gender == 'male' ? '先生' : gender == 'female' ? '女士' : ''}';
    final memoCount = memoEntries.length;
    final isClosed = status == 'closed';

    final avatarColor = gender == 'male' ? Colors.blue : Colors.pink;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isClosed ? 0 : 1,
      color: isClosed ? Colors.grey.withValues(alpha: 0.08) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isClosed
                    ? Colors.grey.withValues(alpha: 0.3)
                    : avatarColor.withValues(alpha: 0.15),
                child: Icon(
                  gender == 'male' ? Icons.person : Icons.person_2,
                  color: isClosed ? Colors.grey : avatarColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isClosed ? Colors.grey : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isClosed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('已结单',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (requirements.isNotEmpty)
                      Text(
                        requirements,
                        style: TextStyle(
                          fontSize: 13,
                          color: isClosed
                              ? Colors.grey
                              : Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      const Text(
                        '暂无需求描述',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (phone.isNotEmpty) ...[
                          const Icon(Icons.phone,
                              size: 11, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(phone,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 10),
                        ],
                        if (memoCount > 0) ...[
                          const Icon(Icons.sticky_note_2_outlined,
                              size: 11, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text('$memoCount 条跟进',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 10),
                        ],
                        if (updatedAt != null)
                          Text(_relativeTime(updatedAt),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}