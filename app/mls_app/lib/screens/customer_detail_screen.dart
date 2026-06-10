import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../services/customer_service.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_follow_item.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_section_header.dart';
import '../widgets/mls/mls_spec_grid.dart';
import '../widgets/mls/mls_status_badge.dart';

/// 客户详情 V2 — hifi 重设计
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      CustomerService.instance.detail(widget.customerId);

  void _reload() {
    if (!mounted) return;
    setState(() { _future = _load(); _dirty = true; });
  }

  Future<void> _addMemo() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('记一次跟进'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: '跟进内容...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await CustomerService.instance.addMemo(widget.customerId, result);
        if (mounted) _reload();
      } on DioException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败:${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (didPop) return; context.pop(_dirty); },
      child: Scaffold(
        backgroundColor: MlsColors.bgPageStart,
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('加载失败', style: TextStyle(color: MlsColors.danger)));
            }
            final d = snap.data!;
            return _buildContent(d);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final surname = (d['surname'] ?? '').toString();
    final gender = (d['gender'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final requirements = (d['requirements'] ?? '').toString();
    final status = (d['status'] ?? 'active').toString();
    final createdAt = d['created_at'] as String?;
    final isClosed = status == 'closed';
    final isBuyer = requirements.contains('意向') || requirements.contains('预算');
    final accent = isBuyer ? MlsColors.primary : MlsColors.gold;
    final roleLabel = isBuyer ? '买方' : '卖方';
    final displayName = '$surname${gender == 'male' ? '先生' : gender == 'female' ? '女士' : ''}';
    final memoEntries = (d['memo_entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final followups = memoEntries.isNotEmpty
        ? memoEntries
        : _defaultFollowups;

    final daysAgo = createdAt != null
        ? DateTime.now().difference(DateTime.parse(createdAt)).inDays
        : 8;
    final followCount = followups.length;
    final showingCount = followups.where((m) => (m['type'] ?? '').toString().contains('带看')).length;

    return Column(children: [
      Expanded(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: MlsNavBar(title: '客户详情', right: IconButton(icon: Icon(Icons.edit, size: 20, color: MlsColors.textSecondary), onPressed: _addMemo))),
          // 身份卡
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: MlsCard(variant: MlsCardVariant.elevated, child: Column(children: [
            Row(children: [
              MlsAvatar(name: displayName.isNotEmpty ? displayName : '客户', size: 52, onlineStatus: isClosed ? MlsOnlineStatus.none : MlsOnlineStatus.online),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(displayName.isNotEmpty ? displayName : '客户', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 18, fontWeight: FontWeight.w600, color: MlsColors.textPrimary)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(roleLabel, style: TextStyle(fontFamily: MlsTypography.monoFamily, fontFamilyFallback: MlsTypography.monoFallback, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1, color: accent)),
                  ),
                  if (isClosed) ...[
                    const SizedBox(width: 6),
                    MlsStatusBadge(text: '已结单', variant: MlsBadgeVariant.neutral),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('建档 $daysAgo 天 · 跟进 $followCount 次 · 带看 $showingCount 次', style: MlsTypography.body2),
              ])),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: MlsPrimaryButton(text: '拨打电话', leadingIcon: LucideIcons.phone, fullWidth: true, onPressed: () {
                if (phone.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拨号 $phone')));
              })),
              const SizedBox(width: 10),
              Expanded(child: MlsPrimaryButton(text: '微信', variant: MlsButtonVariant.secondary, fullWidth: true, onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制微信号')));
              })),
            ]),
          ])))),
          // 意向网格
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildIntentCard(requirements, isBuyer, phone))),
          // 匹配房源
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildMatchingListings())),
          // 跟进记录
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildFollowSection(followups))),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
      _buildBottomBar(),
    ]);
  }

  Widget _buildIntentCard(String requirements, bool isBuyer, String phone) {
    final parts = requirements.split(' ');
    final specs = <({String k, String v})>[];
    for (final p in parts) {
      final colon = p.indexOf(':');
      if (colon > 0) specs.add((k: p.substring(0, colon), v: p.substring(colon + 1)));
    }
    if (phone.isNotEmpty) specs.add((k: '手机号', v: phone));

    return MlsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isBuyer ? 'DEMAND · 找房需求' : 'PROPERTY · 委托出售', style: MlsTypography.monoLabel),
      if (specs.isNotEmpty) ...[
        const SizedBox(height: 14),
        MlsSpecGrid(items: specs),
      ],
    ]));
  }

  // TODO(prod): remove mock — replace with real API integration for matching listings
  Widget _buildMatchingListings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MlsSectionHeader(title: '匹配房源', trailingLabel: '3 套'),
      MlsCard(variant: MlsCardVariant.flat, onTap: () => context.push('/listing/sample'), child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFE8EDF5), borderRadius: BorderRadius.circular(6)), alignment: Alignment.center, child: const Icon(Icons.image, size: 20, color: Color(0x3D0F172A))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('万达华府 · 3室朝南', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 13, fontWeight: FontWeight.w600, color: MlsColors.textPrimary)),
          const SizedBox(height: 2),
          Row(children: [
            Text('218万', style: TextStyle(fontFamily: MlsTypography.monoFamily, fontFamilyFallback: MlsTypography.monoFallback, fontSize: 14, fontWeight: FontWeight.w700, color: MlsColors.primary, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 8),
            Text('108㎡ · 匹配度 92%', style: MlsTypography.caption1),
          ]),
        ])),
        Icon(Icons.chevron_right, size: 18, color: MlsColors.textTertiary),
      ])),
    ]);
  }

  Widget _buildFollowSection(List<Map<String, dynamic>> followups) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MlsSectionHeader(title: '跟进记录', leadingIcon: Icons.history, trailingLabel: '${followups.length} 条'),
      ...List.generate(followups.length, (i) {
        final f = followups[i];
        final type = (f['type'] ?? '').toString();
        final hasTrace = type.contains('带看');
        return MlsFollowItem(
          icon: _followIcon(type),
          title: _followTitle(type),
          detail: (f['content'] ?? '').toString().isNotEmpty ? f['content'].toString() : _followDetail(type),
          time: (f['created_at'] ?? '').toString().isNotEmpty ? f['created_at'].toString() : 'TODAY · 14:30',
          agent: f['agent_name']?.toString(),
          cur: i == 0,
          traceId: hasTrace ? 'trace_$i' : null,
          onTraceTap: hasTrace ? () => context.push('/trace', extra: {
            'listingName': '万达华府 · 3室朝南', 'partnerName': '李红',
            'partnerRole': 'BA', 'customerName': '客户', 'currentStep': 3, 'laName': '张三',
          }) : null,
          isLast: i == followups.length - 1,
        );
      }),
    ]);
  }

  IconData _followIcon(String type) {
    if (type.contains('电话')) return Icons.phone;
    if (type.contains('带看')) return Icons.visibility;
    if (type.contains('微信')) return Icons.chat;
    return Icons.note_add;
  }

  String _followTitle(String type) {
    if (type.contains('电话')) return '电话回访';
    if (type.contains('带看')) return '完成带看';
    if (type.contains('微信')) return '微信沟通';
    return '建立档案';
  }

  String _followDetail(String type) {
    if (type.contains('电话')) return '客户对万达华府感兴趣，预算匹配';
    if (type.contains('带看')) return '已实地带看万达华府，客户反馈积极';
    if (type.contains('微信')) return '发送了房源链接和户型图';
    return '客户档案建立，初始跟进记录';
  }

  // TODO(prod): remove mock — replace with real followup data from API
  List<Map<String, dynamic>> get _defaultFollowups => [
    {'type': '电话回访', 'content': '', 'created_at': 'TODAY · 14:30', 'agent_name': '张三'},
    {'type': '完成带看', 'content': '', 'created_at': 'TODAY · 10:15', 'agent_name': '张三'},
    {'type': '微信沟通', 'content': '', 'created_at': '6月8日', 'agent_name': '李红'},
    {'type': '建立档案', 'content': '', 'created_at': '6月5日', 'agent_name': '张三'},
  ];

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: MlsColors.bgPageEnd.withValues(alpha: 0.88), border: const Border(top: BorderSide(color: MlsColors.borderLight, width: 0.5))),
      child: SafeArea(top: false, child: Row(children: [
        Expanded(child: MlsPrimaryButton(text: '约带看', leadingIcon: Icons.event, variant: MlsButtonVariant.secondary, fullWidth: true, onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请在房源详情页发起带看')));
        })),
        const SizedBox(width: 10),
        Expanded(child: MlsPrimaryButton(text: '记一次跟进', leadingIcon: Icons.add, variant: MlsButtonVariant.primary, fullWidth: true, onPressed: _addMemo)),
      ])),
    );
  }
}
