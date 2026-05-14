import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../services/dashboard_service.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_progress_ring.dart';
import '../widgets/mls/mls_dual_bar_chart.dart';
import '../widgets/mls/mls_dual_line_chart.dart';
import '../widgets/mls/mls_funnel_chart.dart';
import '../widgets/mls/mls_donut_chart.dart';
import '../widgets/mls/mls_medal_grid.dart';
import '../widgets/mls/mls_medal_inline.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _funnelTab = 0;
  late Future<Map<String, dynamic>> _v6Future;
  Map<String, dynamic>? _v6;

  @override
  void initState() {
    super.initState();
    _v6Future = DashboardService.instance.v6();
  }

  // ── helpers ──

  Map<String, dynamic> _d(String key) =>
      _v6![key] as Map<String, dynamic>;

  num _n(Map m, String k) => (m[k] ?? 0) as num;

  String _fmtInt(num n) => n.round().toString();

  String _fmtYuan(num n) {
    if (n == 0) return '¥0';
    final s = n.round().toString();
    final buf = StringBuffer('¥');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _pct(num n) => '${(n * 100).round()}%';

  List<DualBarData> _parseMonths(Map card, String k1, String k2) {
    final months = card['months'] as List;
    return months.map((m) => DualBarData(
      month: m['month'] as String,
      laValue: (m[k1] as num).toDouble(),
      baValue: (m[k2] as num).toDouble(),
    )).toList();
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MlsColors.bgDashboard,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工作仪表盘',
                style: MlsTypography.pageTitle
                    .copyWith(color: Colors.white)),
            Text('DASHBOARD · 2026',
                style: MlsTypography.monoLabel
                    .copyWith(color: Colors.white38)),
          ],
        ),
        centerTitle: false,
      ),
      floatingActionButton: const SizedBox.shrink(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _v6Future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.white38),
                    const SizedBox(height: 16),
                    Text('加载失败',
                        style: MlsTypography.cardTitleLg
                            .copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(snap.error.toString(),
                        style: MlsTypography.caption1
                            .copyWith(color: Colors.white38),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => setState(() =>
                          _v6Future = DashboardService.instance.v6()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          _v6 = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card1Bonus(),
              const SizedBox(height: 12),
              _card2YearlyTransactions(),
              const SizedBox(height: 12),
              _card3YearlyActivity(),
              const SizedBox(height: 12),
              _card4Funnel(),
              const SizedBox(height: 12),
              _card5Portfolio(),
              const SizedBox(height: 12),
              _card6Credit(),
              const SizedBox(height: 12),
              _card7Medals(),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // ── Card 1: 累计奖金 (gold) ──

  Widget _card1Bonus() {
    final b = _d('bonus');
    final recv = _fmtYuan(_n(b, 'cumulative_received'));
    final recvMonth = _fmtYuan(_n(b, 'month_received'));
    final paid = _fmtYuan(_n(b, 'cumulative_paid'));
    final paidMonth = _fmtYuan(_n(b, 'month_paid'));
    return MlsCard(
      variant: MlsCardVariant.gold,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
                child: _bonusBlock('累计收到', recv, '本月 $recvMonth')),
            Container(width: 1.5, height: 48, color: MlsColors.goldLight),
            Expanded(
                child: _bonusBlock('累计发出', paid, '本月 $paidMonth')),
          ],
        ),
      ),
    );
  }

  Widget _bonusBlock(String label, String amount, String sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: MlsTypography.caption1
                .copyWith(color: MlsColors.goldTextMid)),
        const SizedBox(height: 4),
        Text(amount,
            style: MlsTypography.monoXl
                .copyWith(color: MlsColors.goldTextDark)),
        const SizedBox(height: 2),
        Text(sub,
            style: MlsTypography.monoTinyLabel
                .copyWith(color: MlsColors.goldTextMid)),
      ],
    );
  }

  // ── Card 2: 全年成交 (dark) ──

  Widget _card2YearlyTransactions() {
    final card = _d('yearly_deals');
    final months = _parseMonths(card, 'la', 'ba');
    final totalLa = _fmtInt(_n(card, 'total_la'));
    final totalBa = _fmtInt(_n(card, 'total_ba'));
    final totalAll = _fmtInt(_n(card, 'total_all'));
    return _darkCard(
      title: '全年成交',
      child: Column(
        children: [
          MlsDualBarChart(
            data: months,
            height: 180,
            laColor: MlsColors.success,
            baColor: MlsColors.primaryLight,
            highlightHighLow: true,
          ),
          const SizedBox(height: 10),
          _metricRow3('LA 累计', totalLa, 'BA 累计', totalBa, '合计', totalAll),
        ],
      ),
    );
  }

  // ── Card 3: 全年活跃 (dark) ──

  Widget _card3YearlyActivity() {
    final card = _d('yearly_activity');
    final months = _parseMonths(card, 'showings', 'customers');
    final totalShowings = _fmtInt(_n(card, 'total_showings'));
    final totalCustomers = _fmtInt(_n(card, 'total_customers'));
    final monthlyAvg = _n(card, 'monthly_avg').toStringAsFixed(1);
    return _darkCard(
      title: '全年活跃',
      child: Column(
        children: [
          MlsDualLineChart(
            data: months,
            height: 190,
            line1Color: MlsColors.chartPurple,
            line2Color: MlsColors.chartOrange,
            line1Label: '带看',
            line2Label: '新增客户',
            highlightHighLow: true,
          ),
          const SizedBox(height: 10),
          _metricRow3('累计带看', totalShowings, '累计客户', totalCustomers,
              '月均', monthlyAvg),
        ],
      ),
    );
  }

  // ── Card 4: 转化漏斗 (dark) ──

  Widget _card4Funnel() {
    final f = _d('funnel');
    if (f['ba_only'] == true) {
      return _darkCard(
        title: '转化漏斗',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('BA 视角漏斗 · 暂无 BA 协作数据',
                style: TextStyle(color: Colors.white38)),
          ),
        ),
      );
    }
    final tab = _funnelTab;
    final data = (tab == 0
        ? f['funnel_90days'] as Map
        : f['funnel_total'] as Map);
    final showingRate =
        _pct(tab == 0 ? _n(f, 'showing_rate_90d') : _n(f, 'showing_rate_total'));
    final dealRate =
        _pct(tab == 0 ? _n(f, 'deal_rate_90d') : _n(f, 'deal_rate_total'));
    final overallRate =
        _pct(tab == 0 ? _n(f, 'overall_90d') : _n(f, 'overall_total'));

    final stages = [
      FunnelStage(
          label: '新增',
          count: _n(data, 'new').toInt(),
          betweenLabel: showingRate),
      FunnelStage(
          label: '带看',
          count: _n(data, 'showing').toInt(),
          betweenLabel: dealRate),
      FunnelStage(label: '成交', count: _n(data, 'deal').toInt()),
    ];

    return _darkCard(
      title: '转化漏斗',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _funnelChip(0, '近 90 天'),
          const SizedBox(width: 6),
          _funnelChip(1, '累计'),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          MlsFunnelChart(stages: stages, height: 200),
          const SizedBox(height: 8),
          _metricRow3(
              '带看率', showingRate, '成交率', dealRate, '整体', overallRate),
        ],
      ),
    );
  }

  Widget _funnelChip(int tab, String label) {
    final active = _funnelTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _funnelTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? MlsColors.borderCard
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: MlsTypography.caption1.copyWith(
              color: active ? Colors.white : Colors.white54,
              fontWeight: active ? MlsTypography.semibold : null,
            )),
      ),
    );
  }

  // ── Card 5: 房源分布 (dark) ──

  Widget _card5Portfolio() {
    final p = _d('portfolio');
    final total = _n(p, 'total');
    if (total == 0) {
      return _darkCard(
        title: '房源分布',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('暂无房源数据',
                style: MlsTypography.caption1
                    .copyWith(color: Colors.white38)),
          ),
        ),
      );
    }

    final segs = [
      DonutSegment(
          label: '已成交',
          value: _n(p, 'sold').toDouble(),
          color: MlsColors.success),
      DonutSegment(
          label: '在售',
          value: _n(p, 'on_sale').toDouble(),
          color: MlsColors.primaryLight),
      DonutSegment(
          label: '已下架',
          value: _n(p, 'offline').toDouble(),
          color: MlsColors.textSecondary),
      DonutSegment(
          label: '历史',
          value: _n(p, 'history').toDouble(),
          color: MlsColors.chartPurple),
    ];

    return _darkCard(
      title: '房源分布',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MlsDonutChart(
            segments: segs,
            size: 130,
            strokeWidth: 14,
            showLegend: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: segs
                  .map((seg) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: seg.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text('${seg.label} ${seg.value.round()}',
                                style: MlsTypography.caption1
                                    .copyWith(color: Colors.white70)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 6: 信誉与等级 (dark) ──

  Widget _card6Credit() {
    return _darkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上层: 协作积分 (整行)
          MlsMedalInline(
            icon: LucideIcons.key,
            iconCount: 3,
            iconColor: MlsColors.primary,
            label: '协作积分',
            valueText: '247',
            subtitle: '资深 · ↑12',
            dark: true,
          ),
          Divider(color: Colors.white10, height: 24),
          // 下层: 信用评分 (整行)
          Row(
            children: [
              Text('信用评分',
                  style: MlsTypography.monoLabel
                      .copyWith(color: Colors.white38)),
              const SizedBox(width: 12),
              const Text('4.6',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              MlsProgressRing(
                percent: 0.92,
                size: 36,
                strokeWidth: 4,
                valueColor: MlsColors.warning,
                animate: false,
              ),
              const SizedBox(width: 12),
              ...List.generate(
                  5,
                  (_) => const Icon(LucideIcons.star,
                      size: 12, color: MlsColors.warning)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card 7: 8 级等级徽标 (dark) ──

  Widget _card7Medals() {
    return _darkCard(
      title: '荣誉等级',
      child: MlsMedalGrid(
        levels: MlsMedalGrid.defaultV6Levels,
        currentLevel: 2,
        dark: true,
      ),
    );
  }

  // ── shared widgets ──

  Widget _darkCard(
      {String? title, Widget? trailing, required Widget child}) {
    return MlsCard(
      variant: MlsCardVariant.dark,
      backgroundColor: MlsColors.bgCardDark,
      borderColor: MlsColors.borderCard,
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Text(title,
                      style: MlsTypography.cardTitleLg
                          .copyWith(color: Colors.white)),
                if (trailing != null) trailing,
              ],
            ),
          if (title != null || trailing != null)
            const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _metricRow3(
      String l1, String v1, String l2, String v2, String l3, String v3) {
    return Row(
      children: [
        _metric(l1, v1),
        const SizedBox(width: 16),
        _metric(l2, v2),
        const SizedBox(width: 16),
        _metric(l3, v3),
      ].map((w) => Expanded(child: w)).toList(),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: MlsTypography.monoLabel.copyWith(color: Colors.white38)),
        const SizedBox(height: 2),
        Text(value,
            style: MlsTypography.monoLarge.copyWith(color: Colors.white)),
      ],
    );
  }
}
