import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/dashboard_service.dart';
import '../components/app_card.dart';
import '../components/app_section.dart';
import '../components/app_avatar.dart';

/// 工作台 v2.0 — Gradient Hero + Gold 奖金卡 + 统计 + 动态 + 快捷操作
class HomeScreen extends StatefulWidget {
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
    final todosF = DashboardService.instance.todos();
    final eventsF = DashboardService.instance.recentEvents();
    final results = await Future.wait([todosF, eventsF]);
    return _DashboardAllData(
      todos: (results[0]['todos'] as List).cast<Map<String, dynamic>>(),
      events: (results[1]['events'] as List).cast<Map<String, dynamic>>(),
    );
  }

  void _refresh() => setState(() => _future = _loadAll());

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '还在忙呀';
    if (h < 11) return '早上好';
    if (h < 13) return '午饭时间';
    if (h < 18) return '下午好';
    if (h < 22) return '晚上好';
    return '夜深了';
  }

  void _showMyMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.person_outline), title: Text(_myName), enabled: false),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('退出登录', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); _confirmLogout(context); }),
        ]),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('退出登录'), content: const Text('确定退出?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await _storage.deleteAll();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DashboardAllData>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snap.data ?? _DashboardAllData(todos: [], events: []);
          final activeTodos = data.todos.where((t) { final c = (t['count'] as num?)?.toInt() ?? 0; return c > 0; }).toList();

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(slivers: [
              // ═══ Hero Section ═══
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppTheme.n0,
                flexibleSpace: FlexibleSpaceBar(background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.gradientPrimary),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          GestureDetector(
                            onTap: () => _showMyMenu(context),
                            child: AppAvatar(name: _myName, size: 44),
                          ),
                          const Spacer(),
                          const Icon(LucideIcons.bell, size: 24, color: AppTheme.n0),
                          const SizedBox(width: 12),
                        ]),
                        const SizedBox(height: 16),
                        Text('${_greeting()}，${_myName.isNotEmpty ? _myName : ''}', style: AppTheme.titleL.copyWith(color: AppTheme.n0)),
                        const SizedBox(height: 6),
                        Text('今日有 ${activeTodos.length} 个待办，本月已成交 2 单',
                            style: AppTheme.bodyM.copyWith(color: AppTheme.n0.withValues(alpha: 0.7))),
                      ]),
                    ),
                  ),
                )),
              ),

              // ═══ Gold 奖金卡 ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: AppCard.gold(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('本月奖金', style: AppTheme.caption.copyWith(color: AppTheme.n0.withValues(alpha: 0.7), fontSize: 13))),
                        Text('查看明细 →', style: AppTheme.caption.copyWith(color: AppTheme.n0.withValues(alpha: 0.75))),
                      ]),
                      const SizedBox(height: 8),
                      Text('¥4,800.00', style: AppTheme.numberXL.copyWith(color: AppTheme.n0)),
                      const SizedBox(height: 4),
                      Text('较上月 +¥1,200（↑33%）', style: AppTheme.caption.copyWith(color: AppTheme.n0.withValues(alpha: 0.65), fontSize: 11)),
                    ]),
                  ),
                ),
              ),

              // ═══ 3 Stat Cards ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: activeTodos.take(3).map((todo) {
                    final isLast = todo == activeTodos.last;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 8),
                        child: AppCard.base(
                          padding: const EdgeInsets.all(14),
                          onTap: todo['route'] != null ? () => context.push(todo['route'] as String) : null,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(_iconForTodo(todo['type'] as String?), size: 24, color: _colorForTodo(todo['type'] as String?)),
                            const SizedBox(height: 8),
                            Text(todo['label']?.toString() ?? '', style: AppTheme.caption.copyWith(fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('${todo['count'] ?? 0}', style: _numStyleForTodo(todo['type'] as String?)),
                          ]),
                        ),
                      ),
                    );
                  }).toList()),
                ),
              ),

              // ═══ 今日动态 ═══
              SliverToBoxAdapter(
                child: AppSection(
                  title: '今日动态', actionLabel: '全部 →',
                  children: data.events.isEmpty
                      ? [AppCard.flat(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('暂无新动态', style: AppTheme.bodyM.copyWith(color: AppTheme.n500)))))]
                      : data.events.take(3).map((e) => _buildTimelineCard(e)).toList(),
                ),
              ),

              // ═══ 快捷操作 ═══
              SliverToBoxAdapter(
                child: AppSection(
                  title: '快捷操作',
                  children: [
                    Row(children: [
                      Expanded(child: _buildQuickAction(LucideIcons.plus, '挂新房源', '/listing/new')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickAction(LucideIcons.userPlus, '添加客户', '/customer/new')),
                    ]),
                    Row(children: [
                      Expanded(child: _buildQuickAction(LucideIcons.search, '共享库', '/listings/shared')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickAction(LucideIcons.briefcase, '协作记录', '/home?tab=2')),
                    ]),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> e) {
    final color = _eventColor(e['type'] as String?);
    return AppCard.base(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppTheme.radiusM), bottomLeft: Radius.circular(AppTheme.radiusM)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['time_ago']?.toString() ?? '', style: AppTheme.caption),
              const SizedBox(height: 4),
              Text(e['action_text']?.toString() ?? '', style: AppTheme.bodyM),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, String route) {
    return AppCard.base(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(route),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppTheme.primary50, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: AppTheme.primary500)),
        const SizedBox(width: 12),
        Text(label, style: AppTheme.titleS.copyWith(fontSize: 14)),
      ]),
    );
  }

  IconData _iconForTodo(String? type) {
    switch (type) {
      case 'showing_request': return LucideIcons.userCheck;
      case 'transaction': return LucideIcons.checkCircle;
      default: return LucideIcons.building;
    }
  }

  Color _colorForTodo(String? type) {
    switch (type) {
      case 'showing_request': return AppTheme.warning;
      case 'transaction': return AppTheme.info;
      default: return AppTheme.primary500;
    }
  }

  TextStyle _numStyleForTodo(String? type) {
    return AppTheme.numberL.copyWith(color: _colorForTodo(type));
  }

  Color _eventColor(String? type) {
    switch (type) {
      case 'showing_request': return AppTheme.primary500;
      case 'transaction': return AppTheme.success;
      default: return AppTheme.n200;
    }
  }
}

class _DashboardAllData {
  final List<Map<String, dynamic>> todos;
  final List<Map<String, dynamic>> events;
  _DashboardAllData({required this.todos, required this.events});
}
