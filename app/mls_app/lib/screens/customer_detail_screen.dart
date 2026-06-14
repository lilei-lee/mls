import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../services/customer_service.dart';
import '../utils/customer_labels.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_section_header.dart';
import '../widgets/mls/mls_spec_grid.dart';

/// 客户详情 — 升级版(结构化档案 + 已看房源反馈 + 状态流转)
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<Map<String, dynamic>> _showingsFuture;
  bool _dirty = false;

  static const _statusFlow = [
    ('new', '新客'), ('following', '跟进中'), ('viewed', '已带看'),
    ('deal', '已成交'), ('lost', '已战败'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _showingsFuture = CustomerService.instance.showings(widget.customerId);
  }

  Future<Map<String, dynamic>> _load() =>
      CustomerService.instance.detail(widget.customerId);

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
      _showingsFuture = CustomerService.instance.showings(widget.customerId);
      _dirty = true;
    });
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

  Future<void> _changeStatus() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('更新客户状态', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final s in _statusFlow)
            ListTile(
              leading: Icon(Icons.circle, size: 14, color: customerStatusColor(s.$1)),
              title: Text(s.$2),
              onTap: () => Navigator.pop(ctx, s.$1),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    String? lostReason;
    if (picked == 'lost') {
      final ctrl = TextEditingController();
      lostReason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('战败原因'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '如 预算不够 / 已在别处成交', border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('确定')),
          ],
        ),
      );
      if (lostReason == null || lostReason.isEmpty) return; // 取消或未填原因
    }
    try {
      await CustomerService.instance.update(widget.customerId, {
        'status': picked,
        if (lostReason != null) 'lost_reason': lostReason,
      });
      if (mounted) _reload();
    } on DioException catch (e) {
      if (mounted) {
        final det = e.response?.data?['detail'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败:${det is String ? det : e.message}')));
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
            return _buildContent(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final surname = (d['surname'] ?? '').toString();
    final gender = (d['gender'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final status = (d['status'] ?? 'new').toString();
    final grade = d['intent_grade'] as String?;
    final dueFollow = d['is_follow_up_due'] == true;
    final lostReason = (d['lost_reason'] ?? '').toString();
    final tags = (d['tags'] as List?)?.cast<String>() ?? [];
    final createdAt = d['created_at'] as String?;
    final displayName = '$surname${genderLabel(gender)}';
    final memoEntries = (d['memo_entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final daysAgo = createdAt != null
        ? DateTime.now().difference(DateTime.parse(createdAt)).inDays
        : 0;

    return Column(children: [
      Expanded(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: MlsNavBar(title: '客户详情', right: IconButton(icon: const Icon(Icons.swap_horiz, size: 20, color: MlsColors.textSecondary), onPressed: _changeStatus))),
          // 身份卡
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: MlsCard(variant: MlsCardVariant.elevated, child: Column(children: [
            Row(children: [
              MlsAvatar(name: displayName.isNotEmpty ? displayName : '客户', size: 52),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(displayName.isNotEmpty ? displayName : '客户', overflow: TextOverflow.ellipsis, style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 18, fontWeight: FontWeight.w600, color: MlsColors.textPrimary))),
                  const SizedBox(width: 6),
                  if (grade != null) ...[_badge('$grade类', customerGradeColor(grade)), const SizedBox(width: 4)],
                  _badge(customerStatusLabel(status), customerStatusColor(status)),
                  if (dueFollow) ...[const SizedBox(width: 4), const Icon(Icons.notifications_active, size: 15, color: MlsColors.danger)],
                ]),
                const SizedBox(height: 4),
                Text('建档 $daysAgo 天 · 跟进 ${memoEntries.length} 次', style: MlsTypography.body2),
                if (status == 'lost' && lostReason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('战败原因:$lostReason', style: TextStyle(fontSize: 11, color: MlsColors.danger)),
                ],
              ])),
            ]),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) => _badge(t, MlsColors.primary)).toList())),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: MlsPrimaryButton(text: '拨打电话', leadingIcon: LucideIcons.phone, fullWidth: true, onPressed: () {
                if (phone.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拨号 $phone')));
              })),
              const SizedBox(width: 10),
              Expanded(child: MlsPrimaryButton(text: '更新状态', variant: MlsButtonVariant.secondary, fullWidth: true, onPressed: _changeStatus)),
            ]),
          ])))),
          // 档案
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildProfileCard(d))),
          // 已看房源 + 反馈
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildShowings())),
          // 跟进记录
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildMemos(memoEntries))),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
      _buildBottomBar(),
    ]);
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _buildProfileCard(Map<String, dynamic> d) {
    final specs = <({String k, String v})>[];
    void add(String k, String? v) { if (v != null && v.isNotEmpty) specs.add((k: k, v: v)); }

    final bmin = d['budget_min_wan'], bmax = d['budget_max_wan'];
    if (bmin != null || bmax != null) add('预算', '${bmin ?? '?'}-${bmax ?? '?'}万');
    final districts = (d['intent_districts'] as List?)?.cast<String>() ?? [];
    if (districts.isNotEmpty) add('意向区域', districts.join('、'));
    final comms = (d['intent_communities'] as List?) ?? [];
    if (comms.isNotEmpty) add('意向小区', comms.map((c) => (c as Map)['name']).join('、'));
    final rooms = d['rooms_need'], halls = d['halls_need'], baths = d['baths_need'];
    if (rooms != null || halls != null || baths != null) add('户型', '${rooms ?? 0}室${halls ?? 0}厅${baths ?? 0}卫');
    add('面积', (d['area_need'] ?? '').toString());
    add('目的', (d['purpose'] ?? '').toString());
    add('付款', (d['payment'] ?? '').toString());
    add('来源', (d['source'] ?? '').toString());
    add('手机', (d['phone'] ?? '').toString());
    add('备用', (d['phone_alt'] ?? '').toString());
    add('微信', (d['wechat'] ?? '').toString());
    add('下次跟进', (d['next_follow_up_at'] ?? '').toString());
    final req = (d['requirements'] ?? '').toString();

    return MlsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PROFILE · 客户档案', style: MlsTypography.monoLabel),
      if (specs.isNotEmpty) ...[const SizedBox(height: 14), MlsSpecGrid(items: specs)],
      if (req.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('备注:$req', style: MlsTypography.body2),
      ],
      if (specs.isEmpty && req.isEmpty) Text('暂无档案信息,点右上角或下方完善', style: MlsTypography.caption1),
    ]));
  }

  Widget _buildShowings() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _showingsFuture,
      builder: (ctx, snap) {
        final items = snap.hasData ? (snap.data!['items'] as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MlsSectionHeader(title: '已看房源', trailingLabel: '${items.length} 套'),
          if (snap.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
          else if (items.isEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text('还没有带看记录', style: MlsTypography.caption1))
          else
            ...items.map(_showingCard),
        ]);
      },
    );
  }

  Widget _showingCard(Map<String, dynamic> it) {
    final snap = (it['listing_snapshot'] as Map?) ?? {};
    final title = [snap['community'], snap['building'], snap['unit'], snap['room_no']].where((x) => x != null && x.toString().isNotEmpty).join(' ');
    final time = (it['showing_time'] ?? '').toString();
    final satisfaction = it['satisfaction'] as String?;
    final feedback = (it['customer_feedback'] ?? '').toString();
    final trueNeeds = (it['true_needs'] ?? '').toString();
    final intent = it['intent_result'] as String?;
    final satColor = satisfaction == '满意' ? MlsColors.success : satisfaction == '不满意' ? MlsColors.danger : MlsColors.warning;

    return MlsCard(variant: MlsCardVariant.flat, margin: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title.isEmpty ? '房源' : title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MlsColors.textPrimary), overflow: TextOverflow.ellipsis)),
        if (satisfaction != null) _badge(satisfaction, satColor),
        if (intent != null) ...[const SizedBox(width: 4), _badge(intent, MlsColors.primary)],
      ]),
      if (time.length >= 10) Padding(padding: const EdgeInsets.only(top: 2), child: Text(time.substring(0, 10), style: MlsTypography.caption1)),
      if (feedback.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('反馈:$feedback', style: MlsTypography.body2)),
      if (trueNeeds.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('真实需求:$trueNeeds', style: TextStyle(fontSize: 12, color: MlsColors.primary))),
    ]));
  }

  Widget _buildMemos(List<Map<String, dynamic>> memos) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MlsSectionHeader(title: '跟进记录', leadingIcon: Icons.history, trailingLabel: '${memos.length} 条'),
      if (memos.isEmpty)
        Padding(padding: const EdgeInsets.all(8), child: Text('还没有跟进记录', style: MlsTypography.caption1))
      else
        ...memos.reversed.map((m) => MlsCard(variant: MlsCardVariant.flat, margin: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((m['text'] ?? '').toString(), style: MlsTypography.body2),
          const SizedBox(height: 4),
          Text((m['created_at'] ?? '').toString(), style: MlsTypography.caption1),
        ]))),
    ]);
  }

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
