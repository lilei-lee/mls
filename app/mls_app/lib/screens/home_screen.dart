import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/dashboard_service.dart';

/// 工作台 · Day 11 重写 + Day 15 加退出登录入口
///
/// 新结构(从上到下):
/// 1. 今日待办(逐条版,红/橙卡片,做完消失)
/// 2. 最近动态(过去 24h 事件流,灰色信息性)
/// 3. 快速入口(创建类动作)
///
/// AppBar 右上角头像入口 → 弹底部菜单(Day 15 临时:仅退出登录,完整"我的"页待后续)
class HomeScreen extends StatefulWidget {
  /// 保留参数兼容老路由(当前没用,但保留避免破坏 app_router)
  final String name;
  const HomeScreen({super.key, this.name = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storage = FlutterSecureStorage();

  late Future<_DashboardAllData> _future;
  String _myName = '';

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _loadName();
  }

  Future<void> _loadName() async {
    final n = await _storage.read(key: 'name');
    if (mounted) setState(() => _myName = n ?? '');
  }

  Future<_DashboardAllData> _loadAll() async {
    final todosFuture = DashboardService.instance.todos();
    final eventsFuture = DashboardService.instance.recentEvents();
    final results = await Future.wait([todosFuture, eventsFuture]);
    return _DashboardAllData(
      todos: (results[0]['todos'] as List).cast<Map<String, dynamic>>(),
      events: (results[1]['events'] as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadAll();
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '还在忙呀';
    if (h < 11) return '早上好';
    if (h < 13) return '午饭时间';
    if (h < 18) return '下午好';
    if (h < 22) return '晚上好';
    return '夜深了';
  }

  // ============= "我的"菜单(Day 15 临时实现:仅退出登录) =============

  void _showMyMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_myName.isEmpty ? '我的' : _myName),
              subtitle: const Text('完整"我的"页待后续实现'),
              enabled: false,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                '退出登录',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmLogout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text(
              '退出',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!context.mounted) return;

    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'agent_id');
    await _storage.delete(key: 'name');

    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_myName.isEmpty
            ? _greeting()
            : '$_myName,${_greeting()}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: '我的',
              icon: const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              onPressed: () => _showMyMenu(context),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_DashboardAllData>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _buildError(snap.error.toString());
            }
            final data = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTodosSection(data.todos),
                const SizedBox(height: 24),
                _buildEventsSection(data.events),
                const SizedBox(height: 24),
                _buildQuickActions(),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============= 今日待办区 =============

  Widget _buildTodosSection(List<Map<String, dynamic>> todos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('今天要做',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: todos.isEmpty
                    ? Colors.grey.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Text(
                '${todos.length}',
                style: TextStyle(
                  color: todos.isEmpty ? Colors.grey : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (todos.isEmpty)
          _emptyTodosCard()
        else
          ...todos.map((t) => _TodoCard(
                data: t,
                onTap: () => _handleTodoTap(t),
              )),
      ],
    );
  }

  Widget _emptyTodosCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '今天没有待办,去忙自己的事吧',
              style: TextStyle(color: Colors.green, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTodoTap(Map<String, dynamic> todo) async {
    final route = todo['action_route'] as String?;
    if (route == null || route.isEmpty) return;
    await context.push(route);
    _refresh();
  }

  // ============= 最近动态区 =============

  Widget _buildEventsSection(List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('最近动态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text('· 过去 24 小时',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          _emptyEventsRow()
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: events.asMap().entries.map((entry) {
                final isLast = entry.key == events.length - 1;
                return _EventRow(data: entry.value, isLast: isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _emptyEventsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        '过去 24 小时没有新动态',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
    );
  }

  // ============= 快速入口区 =============

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('快速入口',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.2,
          children: [
            _quickActionTile(
              icon: Icons.add_home_outlined,
              color: Colors.blue,
              label: '录入房源',
              onTap: () => context.push('/listing/new'),
            ),
            _quickActionTile(
              icon: Icons.storefront_outlined,
              color: Colors.teal,
              label: '刷共享库',
              onTap: () => context.push('/listings/shared'),
            ),
            _quickActionTile(
              icon: Icons.person_add_outlined,
              color: Colors.purple,
              label: '添加客户',
              onTap: () => context.push('/customer/new'),
            ),
            _quickActionTile(
              icon: Icons.assignment_outlined,
              color: Colors.orange,
              label: '带看申请',
              onTap: () => context.push('/showing-requests/received'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============= 错误态 =============

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

class _DashboardAllData {
  final List<Map<String, dynamic>> todos;
  final List<Map<String, dynamic>> events;
  _DashboardAllData({required this.todos, required this.events});
}

// ============= 子组件:待办卡片 =============

class _TodoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _TodoCard({required this.data, required this.onTap});

  Color _priorityColor() {
    final p = data['priority'] as String?;
    if (p == 'high') return Colors.red;
    return Colors.orange;
  }

  IconData _parseIcon() {
    final name = data['icon'] as String?;
    switch (name) {
      case 'person_add':
        return Icons.person_add;
      case 'rate_review':
        return Icons.rate_review;
      case 'gavel':
        return Icons.gavel;
      case 'monetization_on':
        return Icons.monetization_on;
      case 'edit':
        return Icons.edit;
      default:
        return Icons.notifications_active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(_parseIcon(), color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['title'] ?? '') as String,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((data['subtitle'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          data['subtitle'] as String,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============= 子组件:动态行 =============

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isLast;

  const _EventRow({required this.data, required this.isLast});

  IconData _parseIcon() {
    final name = data['icon'] as String?;
    switch (name) {
      case 'check_circle':
        return Icons.check_circle;
      case 'cancel':
        return Icons.cancel;
      case 'timer_off':
        return Icons.timer_off;
      case 'person_add':
        return Icons.person_add;
      default:
        return Icons.info_outline;
    }
  }

  Color _parseColor() {
    switch (data['color'] as String?) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'grey':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _relativeTime() {
    final iso = data['time'] as String?;
    if (iso == null) return '';
    try {
      final t = DateTime.parse(iso);
      final diff = DateTime.now().difference(t);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
      if (diff.inHours < 24) return '${diff.inHours} 小时前';
      return '${diff.inDays} 天前';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor();
    return InkWell(
      onTap: () {
        final route = data['route'] as String?;
        if (route != null && route.isNotEmpty) {
          context.push(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.12),
                  ),
                ),
        ),
        child: Row(
          children: [
            Icon(_parseIcon(), color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (data['text'] ?? '') as String,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relativeTime(),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}