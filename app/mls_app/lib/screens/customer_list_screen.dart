import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/customer_service.dart';
import '../widgets/mls/mls_card.dart';
import '../utils/time_format.dart';
import '../utils/customer_labels.dart';

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
  String? _statusFilter; // null=全部
  bool _dueOnly = false;
  String _sort = 'updated_at';

  static const _statusFilters = <(String?, String)>[
    (null, '全部'),
    ('new', '新客'),
    ('following', '跟进中'),
    ('viewed', '已带看'),
    ('deal', '已成交'),
    ('lost', '已战败'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return CustomerService.instance.listMine(
      status: _statusFilter,
      dueOnly: _dueOnly,
      sort: _sort,
    );
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
      body: Column(children: [
        _buildFilterBar(),
        Expanded(child: FutureBuilder<Map<String, dynamic>>(
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
                      style: const TextStyle(color: MlsColors.textTertiary, fontSize: 12.0),
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
      )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreate,
        icon: const Icon(Icons.person_add),
        label: const Text('新建客户'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in _statusFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: _statusFilter == f.$1,
                    onSelected: (_) =>
                        setState(() { _statusFilter = f.$1; _future = _load(); }),
                  ),
                ),
            ]),
          ),
          Row(children: [
            FilterChip(
              label: const Text('待跟进'),
              selected: _dueOnly,
              onSelected: (v) => setState(() { _dueOnly = v; _future = _load(); }),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _sort,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'updated_at', child: Text('最近更新')),
                DropdownMenuItem(value: 'grade', child: Text('按等级')),
                DropdownMenuItem(value: 'follow_up', child: Text('按跟进日')),
                DropdownMenuItem(value: 'created_at', child: Text('最新建档')),
              ],
              onChanged: (v) {
                if (v != null) setState(() { _sort = v; _future = _load(); });
              },
            ),
          ]),
        ],
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
                size: 80, color: MlsColors.borderStrong),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '还没有客户',
              style: TextStyle(color: Colors.grey, fontSize: 16.0),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '点击右上角 [+] 添加第一位客户',
              style: TextStyle(color: Colors.grey, fontSize: 12.0),
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
          const Icon(Icons.error_outline, size: 60, color: MlsColors.danger),
          const SizedBox(height: 16),
          Text('加载失败:$err',
              style: const TextStyle(color: MlsColors.danger),
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

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11.0, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final surname = (data['surname'] ?? '') as String;
    final gender = (data['gender'] ?? '') as String;
    final phone = (data['phone'] ?? '') as String;
    final requirements = (data['requirements'] ?? '') as String;
    final memoEntries =
        (data['memo_entries'] as List?)?.cast<dynamic>() ?? [];
    final status = (data['status'] ?? 'new') as String;
    final grade = data['intent_grade'] as String?;
    final dueFollow = data['is_follow_up_due'] == true;
    final updatedAt = data['updated_at'] as String?;

    final displayName = '$surname${genderLabel(gender)}';
    final memoCount = memoEntries.length;
    final isClosed = status == 'lost' || status == 'closed' || status == 'deal';

    final avatarColor = gender == 'male' ? MlsColors.primary : MlsColors.avatarPink;

    return MlsCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isClosed
                    ? MlsColors.textTertiary.withValues(alpha: 0.3)
                    : avatarColor.withValues(alpha: 0.15),
                child: Icon(
                  gender == 'male' ? Icons.person : Icons.person_2,
                  color: isClosed ? MlsColors.textTertiary : avatarColor,
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
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: isClosed ? MlsColors.textTertiary : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (grade != null) ...[
                          _badge('$grade类', customerGradeColor(grade)),
                          const SizedBox(width: 4),
                        ],
                        _badge(customerStatusLabel(status),
                            customerStatusColor(status)),
                        if (dueFollow) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.notifications_active,
                              size: 14, color: MlsColors.danger),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (requirements.isNotEmpty)
                      Text(
                        requirements,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: isClosed
                              ? MlsColors.textTertiary
                              : MlsColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      const Text(
                        '暂无需求描述',
                        style: TextStyle(color: MlsColors.textTertiary, fontSize: 11.0),
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
                                  fontSize: 11.0, color: Colors.grey)),
                          const SizedBox(width: 10),
                        ],
                        if (memoCount > 0) ...[
                          const Icon(Icons.sticky_note_2_outlined,
                              size: 11, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text('$memoCount 条跟进',
                              style: const TextStyle(
                                  fontSize: 11.0, color: Colors.grey)),
                          const SizedBox(width: 10),
                        ],
                        if (updatedAt != null)
                          Text(relativeTime(updatedAt),
                              style: const TextStyle(
                                  fontSize: 11.0, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MlsColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}