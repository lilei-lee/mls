import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/dashboard_service.dart';
import '../components/app_card.dart';
import '../components/app_section.dart';
import '../components/app_avatar.dart';

/// 工作台 v2.0 — Gradient Hero(140) + 3 统计 + 动态 + 快捷操作
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

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(slivers: [
              // ═══ Hero Section (h=140) ═══
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: AppTheme.n0,
                flexibleSpace: FlexibleSpaceBar(background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.gradientPrimary),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(children: [
                        // Row 1: Avatar + greeting + bell
                        Row(children: [
                          GestureDetector(
                            onTap: () => _showMyMenu(context),
                            child: AppAvatar(name: _myName, size: 32),
                          ),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${_greeting()}，${_myName.isNotEmpty ? _myName : '用户'}',
                                style: AppTheme.titleM.copyWith(color: AppTheme.n0, fontSize: 15)),
                            Text('工作台 · ${_todayLabel()}',
                                style: AppTheme.caption.copyWith(color: AppTheme.n0.withValues(alpha: 0.65), fontSize: 11)),
                          ]),
                          const Spacer(),
                          const Icon(LucideIcons.bell, size: 22, color: AppTheme.n0),
                        ]),
                        const Spacer(),
                        // Row 2: 3 stat columns at bottom of hero
                        Row(children: [
                          _heroStat('${_countForType(data.todos, 'showing_request')}', '待审带看'),
                          _heroDivider(),
                          _heroStat('${_countForType(data.todos, 'transaction')}', '待确认成交'),
                          _heroDivider(),
                          _heroStat('${_countForType(data.todos, 'listing')}', '在售房源'),
                        ]),
                      ]),
                    ),
                  ),
                )),
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

  Widget _heroStat(String count, String label) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(count, style: AppTheme.numberL.copyWith(fontSize: 24, color: AppTheme.n0)),
        const SizedBox(height: 2),
        Text(label, style: AppTheme.caption.copyWith(color: AppTheme.n0.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    );
  }

  Widget _heroDivider() => Container(width: 1, height: 32, color: AppTheme.n0.withValues(alpha: 0.2));

  int _countForType(List<Map<String, dynamic>> todos, String type) {
    final match = todos.where((t) => t['type'] == type).firstOrNull;
    return (match?['count'] as num?)?.toInt() ?? 0;
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${weekdays[now.weekday - 1]} ${now.month}月${now.day}日';
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
