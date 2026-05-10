import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../services/transaction_service.dart';
import '../widgets/base64_image.dart';
import '../models/listing_showing_summary.dart';

/// V2.2 #1: 6-section 详情页 + 权限分层渲染
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<List<ListingShowingSummary>?> _showingsFuture;
  bool _listChanged = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _showingsFuture = _fetchShowingsSummary();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final response = await ApiClient.instance.dio.get('/listings/${widget.listingId}');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<ListingShowingSummary>?> _fetchShowingsSummary() async {
    try {
      final r = await ApiClient.instance.dio.get('/listings/${widget.listingId}/showings-summary');
      final items = (r.data['items'] as List).cast<Map<String, dynamic>>();
      return items.map((e) => ListingShowingSummary.fromJson(e)).toList();
    } catch (_) {
      return null;  // 403 = not owner, or error → skip section
    }
  }

  void _reload() {
    setState(() => _future = _fetch());
    _listChanged = true;
  }

  // ── 下架 / 重新上架 / 交易状态 (same as V2.1) ──
  Future<void> _offline() async {
    final confirmed = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('下架房源'),
        content: const Text('下架后房源在共享库不再展示,但数据会保留。以后可以重新上架。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定下架', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.delete('/listings/${widget.listingId}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房源已下架')));
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下架失败:${e.message}')));
    }
  }

  Future<void> _reactivate() async {
    final confirmed = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('重新上架'), content: const Text('确定把这条房源重新上架到共享库吗?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('重新上架', style: TextStyle(color: Colors.green))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.post('/listings/${widget.listingId}/reactivate');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房源已重新上架')));
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上架失败:${e.message}')));
    }
  }

  Future<void> _openStatusBottomSheet(Map<String, dynamic> item) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _StatusChangeSheet(currentStatus: item['status'] as String, onAction: (action) async {
        Navigator.of(ctx).pop();
        await _handleStatusAction(action);
      }),
    );
  }

  Future<void> _handleStatusAction(String action) async {
    try {
      switch (action) {
        case 'mark_deposit_paid':
          await _confirmAndRun(title: '标记定金已付', content: '确认买家已付定金?', okText: '确认标记', action: () async {
            await ListingStatusService.instance.markDepositPaid(widget.listingId);
          }, successMsg: '已标记为「定金已付」');
        case 'mark_transaction_ongoing':
          await _confirmAndRun(title: '标记成交进行中', content: '确认交易已进入过户流程?', okText: '确认标记', action: () async {
            await ListingStatusService.instance.markTransactionOngoing(widget.listingId);
          }, successMsg: '已标记为「成交进行中」');
        case 'rollback':
          final reason = await showDialog<String>(context: context, builder: (ctx) => const _RollbackReasonDialog());
          if (reason == null) return;
          await ListingStatusService.instance.rollbackToOnSale(widget.listingId, reason);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已回退到「在售」')));
          _reload();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败:${e.message}')));
    }
  }

  Future<void> _confirmAndRun({required String title, required String content, required String okText, required Future<void> Function() action, required String successMsg}) async {
    final ok = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: Text(title), content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(okText, style: const TextStyle(color: Colors.blue))),
        ],
      ),
    );
    if (ok != true) return;
    await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
    _reload();
  }

  // ════════════════ UI ════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, onPopInvokedWithResult: (didPop, _) { if (didPop) return; context.pop(_listChanged); },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('房源详情'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop(_listChanged)),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('加载失败:${snapshot.error}', style: const TextStyle(color: Colors.red)));
            final item = snapshot.data!;
            final status = item['status'] as String;
            final isOffline = status == 'offline';
            final isSold = status == 'sold';
            final isOnSale = status == 'on_sale';
            final isInTransaction = status == 'deposit_paid' || status == 'transaction_ongoing';
            final photos = ((item['photos'] as List?) ?? []).cast<Map<String, dynamic>>();
            final agentRemarks = (item['agent_remarks'] ?? '').toString();
            final showingInst = (item['showing_instructions'] ?? '').toString();
            final isUnlocked = agentRemarks.isNotEmpty || showingInst.isNotEmpty;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _PhotoCarousel(photos: photos),

                // ═══ ①/② 基础信息卡 ═══
                _sectionCard(children: [
                  Row(children: [
                    Expanded(child: Text('${item['community']} ${item['building']}号楼${item['unit']}单元${item['room_no']}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    _StatusBadge(status: status),
                  ]),
                  const SizedBox(height: 8),
                  Text('一户一码:${item['house_code']}', style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  if (isSold) _soldPriceCard(item) else _askingPriceCard(item),
                  const SizedBox(height: 12),
                  // 物理信息行
                  _infoRow('户型', item['layout'] ?? '-'),
                  _infoRow('建筑面积', '${item['area_sqm']}㎡'),
                  _infoRow('楼层', '${item['floor']}/${item['total_floor']}层'),
                  _infoRow('朝向', item['orientation'] ?? '-'),
                  if ((item['district'] ?? '').toString().isNotEmpty) _infoRow('行政区', item['district']),

                  // ★ 格局特点 chips
                  if (_buildObjectiveChips(item) case final w?) w,
                  // ★ 装修徽标(已合入格局行,跳过)

                  const Divider(height: 24),
                  // ★ 小区主页迷你卡
                  _buildCommunityMiniCard(item),
                ]),

                // ═══ ③ 卖点标签 ═══
                if (item['sale_points'] is List && (item['sale_points'] as List).isNotEmpty)
                  _sectionCard(title: '卖点标签', children: [
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: (item['sale_points'] as List).cast<String>().map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200)),
                        child: Text(t, style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
                      )).toList(),
                    ),
                  ]),

                // ═══ ④ 房源描述 ═══
                if ((item['public_remarks'] ?? '').toString().isNotEmpty)
                  _sectionCard(title: '房源描述', children: [
                    Text(item['public_remarks'].toString(), style: const TextStyle(fontSize: 14, height: 1.6)),
                  ]),

                // ═══ ⑤ 协作信息 ═══
                _sectionCard(title: '协作信息', children: [
                  _infoRow('挂牌经纪人', item['owner_agent_name'] ?? '-'),
                  _infoRow('合作奖金', '¥${item['bonus_yuan'] ?? 0} 元'),
                  if (isUnlocked)
                    _infoRow('联系电话', item['owner_agent_phone'] ?? ''),
                ]),

                // ═══ ⑦ V2.2 #3: LA 视角带看记录 ═══
                FutureBuilder<List<ListingShowingSummary>?>(
                  future: _showingsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _sectionCard(title: '带看记录', children: [
                        const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                      ]);
                    }
                    final summaries = snap.data;
                    if (summaries == null) return const SizedBox.shrink();  // BA/error → skip
                    if (summaries.isEmpty) {
                      return _sectionCard(title: '带看记录', children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Icon(Icons.people_outline, size: 24, color: Colors.grey),
                            SizedBox(width: 12),
                            Expanded(child: Text('暂无带看申请,等买方经纪人发现你的房源', style: TextStyle(color: Colors.grey, fontSize: 14))),
                          ]),
                        ),
                      ]);
                    }
                    return _sectionCard(
                      title: '带看记录  ·  共 ${summaries.length} 条',
                      children: summaries.map((s) => _ShowingSummaryCard(summary: s)).toList(),
                    );
                  },
                ),

                // ═══ ⑥ 权限分层 ═══
                if (isUnlocked) ...[
                  _sectionCard(title: '同行私话', children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.lock_open, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(agentRemarks, style: const TextStyle(fontSize: 14, height: 1.6))),
                    ]),
                  ]),
                  if (showingInst.isNotEmpty)
                    _sectionCard(title: '看房安排', children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(showingInst, style: const TextStyle(fontSize: 14, height: 1.6))),
                      ]),
                    ]),
                ] else ...[
                  _sectionCard(children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.lock_outline, size: 24, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('申请通过后展示', style: TextStyle(color: Colors.grey, fontSize: 14))),
                      ]),
                    ),
                  ]),
                ],

                const SizedBox(height: 12),

                // ═══ V2.2 #5: 房源动态 ═══
                _buildActivitySection(item),

                // ═══ V2.2 #5: 同小区同居室 ═══
                _buildSameLayoutSection(item),

                // ── Action buttons ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    if (isSold)
                      _soldActionsSection()
                    else if (isOffline)
                      _offlineActionsSection()
                    else ...[
                      SizedBox(height: 48, child: ElevatedButton.icon(
                        onPressed: () async {
                          final changed = await context.push<bool>('/listing/${widget.listingId}/edit', extra: item);
                          if (changed == true) _reload();
                        },
                        icon: const Icon(Icons.edit), label: const Text('编辑房源'),
                      )),
                      const SizedBox(height: 12),
                      SizedBox(height: 48, child: ElevatedButton.icon(
                        onPressed: () => _openStatusBottomSheet(item),
                        icon: const Icon(Icons.swap_horiz), label: const Text('变更交易状态'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      )),
                      const SizedBox(height: 12),
                      if (isOnSale)
                        SizedBox(height: 48, child: OutlinedButton.icon(
                          onPressed: _offline,
                          icon: const Icon(Icons.archive_outlined), label: const Text('下架'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        )),
                      if (isInTransaction)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: const Row(children: [
                            Icon(Icons.info_outline, color: Colors.grey, size: 18), SizedBox(width: 8),
                            Expanded(child: Text('交易状态下不能直接下架,请先回退到「在售」', style: TextStyle(color: Colors.grey, fontSize: 12))),
                          ]),
                        ),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── V2.2 #5: 房源动态 ──
  Widget _buildActivitySection(Map<String, dynamic> item) {
    final showings7d = (item['showing_count_7d'] as num?)?.toInt() ?? 0;
    final priceHistory = (item['price_history'] as List?) ?? [];
    final listedAt = item['listed_at'] as String?;
    final currentPrice = item['price_wan'];

    final rows = <Widget>[];
    rows.add(Row(children: [
      _miniStat('近7天带看', '$showings7d 次', Icons.visibility),
      const SizedBox(width: 24),
      _miniStat('关注', '0', Icons.favorite_border),  // V3 占位
    ]));

    if (priceHistory.isNotEmpty || listedAt != null) {
      rows.add(const SizedBox(height: 8));
      rows.add(const Text('调价记录', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)));
      rows.add(const SizedBox(height: 4));
      // 挂牌
      if (listedAt != null) {
        final dt = DateTime.tryParse(listedAt);
        rows.add(_timelineRow('首次挂牌 ${currentPrice}万', dt, isFirst: true));
      }
      // 调价记录(倒序)
      for (final h in priceHistory.reversed) {
        final p = h['price_wan'] ?? h['price'];
        final at = h['changed_at']?.toString() ?? '';
        final dt = DateTime.tryParse(at);
        rows.add(_timelineRow('调价至 ${p}万', dt));
      }
    }

    return _sectionCard(title: '房源动态', children: rows);
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ]);
  }

  Widget _timelineRow(String text, DateTime? time, {bool isFirst = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(
            color: isFirst ? Colors.blue : Colors.grey, shape: BoxShape.circle)),
          if (!isFirst) Container(width: 1, height: 20, color: Colors.grey.shade300),
        ]),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: const TextStyle(fontSize: 13)),
          if (time != null) Text('${time.month}月${time.day}日', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
      ]),
    );
  }

  // ── V2.2 #5: 同小区同居室 ──
  Widget _buildSameLayoutSection(Map<String, dynamic> item) {
    final sameLayout = (item['same_layout_listings'] as List?) ?? [];
    final sameLayoutDeals = (item['same_layout_deals'] as List?) ?? [];

    return _sectionCard(title: '同小区 · 同居室', children: [
      Row(children: [
        _sameLayoutTab('在售 ${sameLayout.length}', true),
        const SizedBox(width: 8),
        _sameLayoutTab('成交 ${sameLayoutDeals.length}', false),
      ]),
      const SizedBox(height: 8),
      if (sameLayout.isEmpty)
        const Text('暂无同居室在售房源', style: TextStyle(color: Colors.grey, fontSize: 13))
      else
        ...sameLayout.take(3).map((l) => _sameLayoutCard(l as Map<String, dynamic>)),
    ]);
  }

  Widget _sameLayoutTab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: active ? Border.all(color: Colors.blue.shade300) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.blue : Colors.grey)),
    );
  }

  Widget _sameLayoutCard(Map<String, dynamic> l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => context.push('/listing/${l['listing_id']}'),
        child: Row(children: [
          Text('${l['building']}-${l['unit']}-${l['room_no']}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text('${l['layout']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text('¥${l['price_wan']}万', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
        ]),
      ),
    );
  }

  // ── Section wrapper ──
  Widget _sectionCard({String? title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
            ],
            ...children,
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]),
    );
  }

  // ── 格局特点 chips ──
  Widget? _buildObjectiveChips(Map<String, dynamic> item) {
    final of = item['objective_features'];
    if (of is! List || of.isEmpty) return null;
    final deco = item['decoration']?.toString();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        ...of.cast<String>().map((f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
          child: Text(f, style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
        )),
        if (deco != null && deco.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade200)),
            child: Text('装修:$deco', style: TextStyle(fontSize: 12, color: Colors.amber.shade800)),
          ),
      ]),
    );
  }

  // ── 小区迷你卡 ──
  Widget _buildCommunityMiniCard(Map<String, dynamic> item) {
    final cf = item['community_features'];
    if (cf is! Map || cf.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey),
          SizedBox(width: 8),
          Text('小区资料补充中', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      );
    }

    final lines = <String>[];

    final bldStart = cf['bld_year_start'];
    final bldEnd = cf['bld_year_end'];
    final totalBld = cf['total_buildings'];
    if (bldStart != null || totalBld != null) {
      final parts = <String>[];
      if (bldStart != null) {
        parts.add('建成 ${bldStart}${bldEnd != null && bldEnd != bldStart ? '-$bldEnd' : ''}');
      }
      if (totalBld != null) parts.add('共 $totalBld 栋');
      lines.add(parts.join(' | '));
    }

    final pCompany = cf['property_company']?.toString();
    final pFee = cf['property_fee_yuan'];
    if (pCompany != null && pCompany.isNotEmpty || pFee != null) {
      final parts = <String>[];
      if (pCompany != null && pCompany.isNotEmpty) parts.add('物业 $pCompany');
      if (pFee != null) parts.add('物业费 $pFee 元/㎡/月');
      lines.add(parts.join(' | '));
    }

    final heating = cf['heating_type']?.toString();
    final school = cf['primary_school']?.toString();
    if (heating != null && heating.isNotEmpty || school != null && school.isNotEmpty) {
      final parts = <String>[];
      if (heating != null && heating.isNotEmpty) parts.add(heating);
      if (school != null && school.isNotEmpty) parts.add('学区:$school');
      lines.add(parts.join(' | '));
    }

    final station = cf['nearest_train_station']?.toString();
    if (station != null && station.isNotEmpty) {
      lines.add('最近高铁站:$station');
    }

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey),
          SizedBox(width: 8),
          Text('小区资料补充中', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      );
    }

    final cid = item['community_id']?.toString();

    return InkWell(
      onTap: cid != null ? () => context.push('/community/$cid') : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.apartment, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(item['community']?.toString() ?? '小区信息', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (cid != null) const Icon(Icons.chevron_right, size: 18, color: Colors.blue),
          ]),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          )),
        ]),
      ),
    );
  }

  Widget _askingPriceCard(Map<String, dynamic> item) => Card(
    color: Colors.red.withValues(alpha: 0.05),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        const Text('挂牌价', style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(width: 12),
        Text('¥${item['price_wan']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(width: 4), const Text('万', style: TextStyle(color: Colors.red, fontSize: 14)),
      ]),
    ),
  );

  Widget _soldPriceCard(Map<String, dynamic> item) {
    final soldPriceYuan = item['sold_price_yuan'];
    final soldDate = item['sold_date'] as String?;
    final wan = soldPriceYuan != null ? ((soldPriceYuan as num) / 10000).toStringAsFixed(1) : '-';
    return Card(
      color: Colors.green.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            const Text('成交价', style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(width: 12),
            Text('¥$wan', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(width: 4), const Text('万', style: TextStyle(color: Colors.green, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: Colors.grey), const SizedBox(width: 4),
            Text('成交日期:${soldDate ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 12), const Text('·', style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(width: 12),
            Text('原挂牌:¥${item['price_wan']}万', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _soldActionsSection() => Card(
    color: Colors.green.withValues(alpha: 0.05),
    child: const Padding(padding: EdgeInsets.all(16), child: Row(children: [
      Icon(Icons.check_circle, color: Colors.green, size: 20), SizedBox(width: 10),
      Expanded(child: Text('该房源已通过成交确认流程生效,不可再编辑。', style: TextStyle(color: Colors.green))),
    ])),
  );

  Widget _offlineActionsSection() => Column(children: [
    Card(color: Colors.grey.withValues(alpha: 0.1), child: const Padding(padding: EdgeInsets.all(16), child: Row(children: [
      Icon(Icons.info_outline, color: Colors.grey, size: 20), SizedBox(width: 10),
      Expanded(child: Text('该房源已下架,在共享库不再展示', style: TextStyle(color: Colors.grey))),
    ]))),
    const SizedBox(height: 16),
    SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _reactivate, icon: const Icon(Icons.unarchive), label: const Text('重新上架'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))),
  ]);
}

// ═══════════════════════ 原有组件保留 ═══════════════════════

class _StatusChangeSheet extends StatelessWidget {
  final String currentStatus;
  final void Function(String action) onAction;
  const _StatusChangeSheet({required this.currentStatus, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        const Icon(Icons.swap_horiz, color: Colors.orange), const SizedBox(width: 8),
        const Text('变更交易状态', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('当前:${_label(currentStatus)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
      const Divider(height: 1),
      if (currentStatus == 'on_sale') ...[
        _tile(icon: Icons.payment, color: Colors.orange, title: '标记「定金已付」', subtitle: '买家已付定金', onTap: () => onAction('mark_deposit_paid')),
        _tile(icon: Icons.fact_check, color: Colors.blue, title: '直接标记「成交进行中」', subtitle: '无定金交易直接签约', onTap: () => onAction('mark_transaction_ongoing')),
      ] else if (currentStatus == 'deposit_paid') ...[
        _tile(icon: Icons.fact_check, color: Colors.blue, title: '标记「成交进行中」', subtitle: '过户流程启动', onTap: () => onAction('mark_transaction_ongoing')),
        _tile(icon: Icons.undo, color: Colors.red, title: '回退到「在售」', subtitle: '买方反悔或交易取消', onTap: () => onAction('rollback')),
      ] else if (currentStatus == 'transaction_ongoing') ...[
        _tile(icon: Icons.undo, color: Colors.red, title: '回退到「在售」', subtitle: '交易取消,需要选原因', onTap: () => onAction('rollback')),
        const Padding(padding: EdgeInsets.all(16), child: Text('进入已售:只能通过 BA 发起的成交确认流程自动触发,不能手动操作。', style: TextStyle(color: Colors.grey, fontSize: 12))),
      ] else ...[
        const Padding(padding: EdgeInsets.all(24), child: Text('当前状态不支持手动切换', style: TextStyle(color: Colors.grey))),
      ],
    ])));
  }

  Widget _tile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  String _label(String s) {
    switch (s) {
      case 'on_sale': return '在售';
      case 'deposit_paid': return '定金已付';
      case 'transaction_ongoing': return '成交进行中';
      case 'sold': return '已成交';
      case 'offline': return '已下架';
      default: return s;
    }
  }
}

class _RollbackReasonDialog extends StatefulWidget { const _RollbackReasonDialog(); @override State<_RollbackReasonDialog> createState() => _RollbackReasonDialogState(); }
class _RollbackReasonDialogState extends State<_RollbackReasonDialog> {
  final _controller = TextEditingController();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('回退到「在售」'),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('请填写回退原因:', style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 10),
      TextField(controller: _controller, maxLines: 2, maxLength: 100, autofocus: true,
          decoration: const InputDecoration(hintText: '如:买方反悔', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      const Text('⚠️ 若该房源有正在进行的成交确认,请先由 BA 撤回后再回退', style: TextStyle(color: Colors.orange, fontSize: 11)),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
      TextButton(onPressed: () {
        final t = _controller.text.trim();
        if (t.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写原因'))); return; }
        Navigator.of(context).pop(t);
      }, child: const Text('确认回退', style: TextStyle(color: Colors.red))),
    ],
  );
}

// ═══════════════════════ 照片轮播 (same) ═══════════════════════

class _PhotoCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  const _PhotoCarousel({required this.photos});
  @override State<_PhotoCarousel> createState() => _PhotoCarouselState();
}
class _PhotoCarouselState extends State<_PhotoCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;
  @override void initState() { super.initState(); _pageController = PageController(); }
  @override void dispose() { _pageController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(height: 200, color: Colors.grey.shade200, alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 48),
        const SizedBox(height: 8), Text('暂无照片', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]));
    }
    return AspectRatio(aspectRatio: 4/3, child: Stack(children: [
      PageView.builder(
        controller: _pageController, itemCount: widget.photos.length, onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _openFullscreen(i),
          child: Container(color: Colors.black, child: Base64Image(dataUrl: widget.photos[i]['data'] as String?, fit: BoxFit.cover)),
        ),
      ),
      Positioned(right: 12, bottom: 12, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
        child: Text('${_currentIndex+1}/${widget.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
      )),
    ]));
  }
  void _openFullscreen(int i) => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FullscreenViewer(photos: widget.photos, initialIndex: i)));
}

class _FullscreenViewer extends StatefulWidget {
  final List<Map<String, dynamic>> photos; final int initialIndex;
  const _FullscreenViewer({required this.photos, required this.initialIndex});
  @override State<_FullscreenViewer> createState() => _FullscreenViewerState();
}
class _FullscreenViewerState extends State<_FullscreenViewer> {
  late PageController _controller; late int _currentIndex;
  @override void initState() { super.initState(); _currentIndex = widget.initialIndex; _controller = PageController(initialPage: widget.initialIndex); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${_currentIndex+1}/${widget.photos.length}'), elevation: 0),
    body: PageView.builder(
      controller: _controller, itemCount: widget.photos.length, onPageChanged: (i) => setState(() => _currentIndex = i),
      itemBuilder: (ctx, i) => Center(child: InteractiveViewer(minScale: 1, maxScale: 4,
          child: Base64Image(dataUrl: widget.photos[i]['data'] as String?, fit: BoxFit.contain))),
    ),
  );
}

/// V2.2 #3: 带看记录卡片
class _ShowingSummaryCard extends StatelessWidget {
  final ListingShowingSummary summary;
  const _ShowingSummaryCard({required this.summary});

  static const _statusColors = {
    'pending': Colors.amber,
    'approved': Colors.green,
    'showing_done': Colors.blue,
    'transaction_initiated': Colors.blue,
    'transaction_confirmed': Colors.indigo,
    'rejected': Colors.grey,
    'canceled': Colors.grey,
  };

  String _maskPhone(String phone) {
    if (phone.length < 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(7)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[summary.currentStatus] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(summary.baName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(summary.currentStatusLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${summary.customerName}${summary.customerDemand != null && summary.customerDemand!.isNotEmpty ? ' · ${summary.customerDemand}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Text('${summary.createdAt.month}月${summary.createdAt.day}日', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            if (summary.baPhone != null)
              InkWell(
                onTap: () {
                  // Simple fallback — url_launcher integration
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.phone, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('拨号 ${_maskPhone(summary.baPhone!)}', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status; const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    late String label; late Color color;
    switch (status) {
      case 'on_sale': label = '在售'; color = Colors.green; break;
      case 'deposit_paid': label = '定金已付'; color = Colors.orange; break;
      case 'transaction_ongoing': label = '成交进行中'; color = Colors.blue; break;
      case 'sold': label = '已成交'; color = Colors.grey; break;
      case 'paused': label = '暂停'; color = Colors.orange; break;
      case 'offline': label = '已下架'; color = Colors.grey; break;
      default: label = status; color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}
