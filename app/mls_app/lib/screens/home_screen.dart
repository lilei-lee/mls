import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_section_header.dart';
import '../widgets/mls/mls_status_badge.dart';
import '../widgets/mls/mls_metric_cell.dart';
import '../widgets/mls/mls_hero_today.dart';
import '../theme/mls_radius.dart';
import '../services/dashboard_service.dart';
import '../services/qna_service.dart';

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
  int _unreadCount = 0;
  int _pendingQnaCount = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final n = await _storage.read(key: 'name');
    if (mounted) setState(() => _myName = n ?? '');
  }

  Future<_DashboardAllData> _loadAll() async {
    final todosF = DashboardService.instance.todos();
    final eventsF = DashboardService.instance.recentEvents();
    final summaryF = DashboardService.instance.summary();
    final results = await Future.wait([todosF, eventsF, summaryF]);
    final todosData = results[0];
    if (mounted) setState(() => _unreadCount = 3); // TODO(prod): remove mock
    // V2.5: 我的提问 pending 数
    try { final c = await QnaService.instance.getMyPendingCount(); if (mounted) setState(() => _pendingQnaCount = c); } catch (_) {}
    Map<String, dynamic> summary;
    try {
      summary = Map<String, dynamic>.from(results[2]);
    } catch (_) {
      summary = {};
    }
    return _DashboardAllData(
      todoItems: (todosData['todos'] as List).cast<Map<String, dynamic>>(),
      todoTotal: (todosData['total'] as num?)?.toInt() ?? 0,
      events: (results[1]['events'] as List).cast<Map<String, dynamic>>(),
      summary: summary,
    );
  }

  void _refresh() => setState(() => _future = _loadAll());

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '凌晨好';
    if (h < 11) return '早上好';
    if (h < 13) return '中午好';
    if (h < 18) return '下午好';
    if (h < 22) return '晚上好';
    return '深夜了，早些休息';
  }

  void _showMyMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.person_outline), title: Text(_myName), enabled: false),
          const Divider(height: 1),
          ListTile(leading: const Icon(LucideIcons.helpCircle), title: const Text('我的提问'),
              trailing: _pendingQnaCount > 0 ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: MlsColors.warningBg, borderRadius: BorderRadius.circular(4)), child: Text('$_pendingQnaCount', style: const TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 10, color: MlsColors.warning, fontWeight: MlsTypography.semibold))) : null,
              onTap: () { Navigator.pop(ctx); context.push('/my-questions'); }),
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
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DashboardAllData>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snap.data ?? _DashboardAllData(todoItems: [], todoTotal: 0, events: []);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(slivers: [
              // ═══ Hero Section (h=100, compact) ═══
              SliverAppBar(
                expandedHeight: 100,
                pinned: true,
                backgroundColor: MlsColors.bgCardPrimary,
                flexibleSpace: FlexibleSpaceBar(background: Container(
                  decoration: const BoxDecoration(gradient: MlsColors.heroBlue),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          onLongPress: () => _showMyMenu(context),
                          child: MlsAvatar(name: _myName, size: 32),
                        ),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Spacer(),
                          Text('${_greeting()}，${_myName.isNotEmpty ? _myName : '用户'}',
                              style: const TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 15, fontWeight: MlsTypography.semibold, color: Colors.white)),
                          Text('工作台 · ${_todayLabel()}',
                              style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                          const Spacer(),
                        ]),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/notifications'),
                          child: Stack(clipBehavior: Clip.none, children: [
                            const Icon(LucideIcons.bell, size: 22, color: Colors.white),
                            if (_unreadCount > 0)
                              Positioned(right: -6, top: -4, child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: const BoxDecoration(color: MlsColors.danger, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                alignment: Alignment.center,
                                child: Text('${_unreadCount > 99 ? '99+' : _unreadCount}', style: const TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 9, fontWeight: MlsTypography.bold, color: Colors.white)),
                              )),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                )),
              ),

              // ═══ Hero Today (mock) ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: MlsHeroToday(
                    topLabel: 'TODAY · 15:00',
                    subtitle: '今日带看 · 与李红协同',
                    countdownTarget: DateTime.now().add(const Duration(hours: 3, minutes: 28)),
                    title: '万达华府 · 3室朝南',
                    description: '108㎡ · 客户王先生 · 已二次咨询',
                    collaborators: const ['李红', '王先生'],
                    ctaText: '立即准备',
                    onCtaPressed: () {
                      context.push('/trace', extra: {
                        'listingName': '万达华府 · 3室朝南',
                        'partnerName': '李红',
                        'partnerRole': 'BA',
                        'customerName': '客户王先生',
                        'currentStep': 3,
                        'laName': '张三',
                      });
                    },
                  ),
                ),
              ),

              // ═══ 4 Metric Panel ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: MlsCard(
                    child: Column(children: [
                      Row(children: [
                        Text('REAL-TIME · 实时', style: MlsTypography.monoLabel),
                        const Spacer(),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          GestureDetector(
                            onTap: () => context.push('/dashboard'),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('仪表盘', style: TextStyle(
                                fontFamilyFallback: MlsTypography.sansFallback,
                                fontSize: 11, color: MlsColors.primary,
                                fontWeight: MlsTypography.semibold,
                              )),
                              Icon(Icons.arrow_outward, size: 12, color: MlsColors.primary),
                            ]),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: MlsMetricCell(
                          label: '待办',
                          value: (() {
                            final s = data.summary;
                            final n = ((s['pending_approval_count'] ?? 0) as int) +
                                      ((s['pending_confirm_showing_count'] ?? 0) as int) +
                                      ((s['pending_confirm_transaction_count'] ?? 0) as int) +
                                      ((s['pending_settlement_count'] ?? 0) as int);
                            return n.toString().padLeft(2, '0');
                          })(),
                          valueColor: MlsColors.danger,
                          padding: EdgeInsets.zero,
                        )),
                        Expanded(child: MlsMetricCell(
                          label: '今日上新',
                          value: ((data.summary['shared_new_today_count'] ?? 0) as int).toString().padLeft(2, '0'),
                          valueColor: MlsColors.primary,
                          padding: EdgeInsets.zero,
                        )),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        const Expanded(child: MlsMetricCell(
                          label: '本月奖金',
                          value: '¥0',
                          valueColor: MlsColors.gold,
                          padding: EdgeInsets.zero,
                        )),
                        Expanded(child: MlsMetricCell(
                          label: '在售房源',
                          value: ((data.summary['my_on_sale_count'] ?? 0) as int).toString().padLeft(2, '0'),
                          valueColor: MlsColors.textPrimary,
                          padding: EdgeInsets.zero,
                        )),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ═══ 协作 row (mock) ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: MlsCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: MlsColors.success)),
                        const SizedBox(width: 8),
                        Text('协作中 · 7 人在线', style: MlsTypography.cardTitleLg),
                        const Spacer(),
                        Text('SEE ALL ↗', style: MlsTypography.monoLabel.copyWith(color: MlsColors.primary)),
                      ]),
                      const SizedBox(height: 12),
                      const MlsAvatarStack(
                        names: ['李红', '王明', '周丽', '陈强', '杨敏'],
                        moreCount: 2,
                        avatarSize: 36,
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.edit_outlined, size: 13, color: MlsColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('李红 正在编辑成交确认 · 刚刚', style: MlsTypography.body2),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ═══ 待办列表 ═══
              SliverToBoxAdapter(
                child: _wrapSection(
                  title: '待办',
                  actionLabel: data.todoTotal > 0 ? '全部 →' : null,
                  children: data.todoTotal > 0
                      ? data.todoItems.take(5).map((todo) => _buildTodoCard(todo, context)).toList()
                      : [MlsCard(variant: MlsCardVariant.flat, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            const Icon(LucideIcons.checkCircle, size: 18, color: MlsColors.success),
                            const SizedBox(width: 8),
                            Text('待办都处理完了 · 保持节奏', style: MlsTypography.body1.copyWith(color: MlsColors.textPrimary)),
                          ]))],
                ),
              ),

              // ═══ 今日动态 ═══
              SliverToBoxAdapter(
                child: _wrapSection(
                  title: '今日动态', actionLabel: '全部 →',
                  children: data.events.isEmpty
                      ? [MlsCard(variant: MlsCardVariant.flat, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            const Icon(LucideIcons.inbox, size: 18, color: MlsColors.textTertiary),
                            const SizedBox(width: 8),
                            Text('暂无新动态', style: MlsTypography.body1.copyWith(color: MlsColors.textTertiary)),
                          ]))]
                      : data.events.take(3).map((e) => _buildTimelineCard(e)).toList(),
                ),
              ),

              // ═══ 快捷操作 ═══
              SliverToBoxAdapter(
                child: _wrapSection(
                  title: '快捷操作',
                  children: [
                    Row(children: [
                      Expanded(child: _buildQuickAction(LucideIcons.plus, '挂新房源', '/listing/new')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickAction(LucideIcons.userPlus, '添加客户', '/customer/new')),
                    ]),
                    Row(children: [
                      Expanded(child: _buildQuickAction(
                        LucideIcons.search, '共享库', '/listings/shared',
                        badge: (data.summary['shared_new_today_count'] ?? 0) as int,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickAction(LucideIcons.briefcase, '协作记录', '/home?tab=2')),
                    ]),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> e) {
    final color = _eventColor(e['type'] as String?);
    return MlsCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(MlsRadius.xl), bottomLeft: Radius.circular(MlsRadius.xl)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['time_ago']?.toString() ?? '', style: MlsTypography.caption1),
              const SizedBox(height: 4),
              Text(e['action_text']?.toString() ?? '', style: MlsTypography.body1),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, String route, {int? badge}) {
    return MlsCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(route),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: MlsColors.primaryBg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: MlsColors.primary),
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: MlsColors.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MlsColors.bgCardPrimary, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  badge > 99 ? '99+' : badge.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: MlsTypography.monoFamily,
                    fontFamilyFallback: MlsTypography.monoFallback,
                    fontSize: 10,
                    fontWeight: MlsTypography.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 14, fontWeight: MlsTypography.semibold, color: MlsColors.textPrimary)),
      ]),
    );
  }

  Widget _buildTodoCard(Map<String, dynamic> todo, BuildContext context) {
    final color = switch (todo['priority']) {
      'high' => MlsColors.warning,
      _ => MlsColors.primary,
    };
    final icon = switch (todo['icon']) {
      'person_add' => LucideIcons.userPlus,
      'rate_review' => LucideIcons.fileText,
      'gavel' => LucideIcons.gavel,
      'monetization_on' => LucideIcons.banknote,
      'edit' => LucideIcons.pencil,
      'user_check' => LucideIcons.userCheck,
      'circle_check' => LucideIcons.checkCircle,
      'handshake' => Icons.handshake_outlined,
      'hourglass_empty' => LucideIcons.hourglass,
      'help_circle' => LucideIcons.helpCircle,
      'person_pin' => Icons.person_pin,
      _ => LucideIcons.bell,
    };
    final route = todo['action_route'] as String?;
    final badge = _todoBadge(todo['type'] as String?);

    return MlsCard(
      padding: const EdgeInsets.all(14),
      onTap: route != null ? () => context.push(route) : null,
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(todo['title']?.toString() ?? '', style: const TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 14, fontWeight: MlsTypography.semibold, color: MlsColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (badge != null) ...[const SizedBox(width: 6), badge],
          ]),
          if (todo['subtitle'] != null && (todo['subtitle'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(todo['subtitle'] as String, style: MlsTypography.body2, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ])),
        if (route != null) const Icon(LucideIcons.chevronRight, size: 18, color: MlsColors.textTertiary),
      ]),
    );
  }

  Widget? _todoBadge(String? type) => switch (type) {
    'transaction_pending_confirm' => const MlsStatusBadge(text: '7天内', variant: MlsBadgeVariant.warning),
    'transaction_waiting_la' => const MlsStatusBadge(text: '进行中', variant: MlsBadgeVariant.info),
    'answer_pending' => const MlsStatusBadge(text: '待回复', variant: MlsBadgeVariant.info),
    _ => null,
  };

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${weekdays[now.weekday - 1]} ${now.month}月${now.day}日';
  }

  Color _eventColor(String? type) {
    switch (type) {
      case 'showing_request': return MlsColors.primary;
      case 'transaction': return MlsColors.success;
      default: return MlsColors.borderStrong;
    }
  }
  // ═══ Section 容器 helper (4A.2.c.3) ═══
  // 等价于旧 AppSection: 标题栏 + children 列表 + 底部 24 间距
  Widget _wrapSection({
    required String title,
    String? actionLabel,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MlsSectionHeader(
            title: title,
            trailing: actionLabel != null
                ? Text(actionLabel, style: const TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 12,
                    fontWeight: MlsTypography.semibold,
                    color: MlsColors.primary,
                  ))
                : null,
          ),
        ),
        const SizedBox(height: 12),
        for (final child in children) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _DashboardAllData {
  final List<Map<String, dynamic>> todoItems;
  final int todoTotal;
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic> summary;
  _DashboardAllData({required this.todoItems, required this.todoTotal, required this.events, this.summary = const {}});
}
