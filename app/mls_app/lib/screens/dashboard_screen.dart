import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
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
  int _funnelTab = 0; // 0=近90天, 1=累计

  static const _yearlyTransactions = [
    DualBarData(month: '1月', laValue: 2, baValue: 1),
    DualBarData(month: '2月', laValue: 3, baValue: 2),
    DualBarData(month: '3月', laValue: 5, baValue: 3),
    DualBarData(month: '4月', laValue: 4, baValue: 2),
    DualBarData(month: '5月', laValue: 6, baValue: 4),
    DualBarData(month: '6月', laValue: 7, baValue: 5),
    DualBarData(month: '7月', laValue: 6, baValue: 4),
    DualBarData(month: '8月', laValue: 5, baValue: 3),
    DualBarData(month: '9月', laValue: 5, baValue: 4),
    DualBarData(month: '10月', laValue: 8, baValue: 6),
    DualBarData(month: '11月', laValue: 6, baValue: 4),
    DualBarData(month: '12月', laValue: 4, baValue: 3),
  ];

  static const _yearlyActivity = [
    DualBarData(month: '1月', laValue: 10, baValue: 6),
    DualBarData(month: '2月', laValue: 12, baValue: 8),
    DualBarData(month: '3月', laValue: 18, baValue: 12),
    DualBarData(month: '4月', laValue: 14, baValue: 10),
    DualBarData(month: '5月', laValue: 20, baValue: 14),
    DualBarData(month: '6月', laValue: 22, baValue: 14),
    DualBarData(month: '7月', laValue: 18, baValue: 12),
    DualBarData(month: '8月', laValue: 16, baValue: 10),
    DualBarData(month: '9月', laValue: 18, baValue: 11),
    DualBarData(month: '10月', laValue: 26, baValue: 16),
    DualBarData(month: '11月', laValue: 20, baValue: 13),
    DualBarData(month: '12月', laValue: 22, baValue: 15),
  ];

  static const _funnelStages90 = [
    FunnelStage(label: '新增', count: 24, betweenLabel: '75%'),
    FunnelStage(label: '带看', count: 18, betweenLabel: '33%'),
    FunnelStage(label: '成交', count: 6),
  ];

  static const _funnelStagesAll = [
    FunnelStage(label: '新增', count: 85, betweenLabel: '65%'),
    FunnelStage(label: '带看', count: 55, betweenLabel: '51%'),
    FunnelStage(label: '成交', count: 28),
  ];

  static const _donutSegments = [
    DonutSegment(label: '已成交', value: 19, color: MlsColors.success),
    DonutSegment(label: '在售', value: 12, color: MlsColors.primaryLight),
    DonutSegment(label: '到期', value: 2, color: MlsColors.warning),
    DonutSegment(label: '已下架', value: 3, color: MlsColors.textSecondary),
    DonutSegment(label: '历史', value: 31, color: MlsColors.chartPurple),
  ];

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
      body: ListView(
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
      ),
    );
  }

  // ── Card 1: 累计奖金 (gold) ──
  Widget _card1Bonus() {
    return MlsCard(
      variant: MlsCardVariant.gold,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
                child: _bonusBlock('累计收到', '¥48,200', '本月 ¥8,400')),
            Container(width: 1.5, height: 48, color: MlsColors.goldLight),
            Expanded(
                child: _bonusBlock('累计发出', '¥12,600', '本月 ¥3,200')),
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
    final laTotal =
        _yearlyTransactions.fold<double>(0, (s, d) => s + d.laValue);
    final baTotal =
        _yearlyTransactions.fold<double>(0, (s, d) => s + d.baValue);
    return _darkCard(
      title: '全年成交',
      child: Column(
        children: [
          MlsDualBarChart(
            data: _yearlyTransactions,
            height: 180,
            laColor: MlsColors.success,
            baColor: MlsColors.primaryLight,
            highlightHighLow: true,
          ),
          const SizedBox(height: 10),
          _metricRow3('LA 累计', '${laTotal.round()}', 'BA 累计',
              '${baTotal.round()}', '合计', '${(laTotal + baTotal).round()}'),
        ],
      ),
    );
  }

  // ── Card 3: 全年活跃 (dark) ──
  Widget _card3YearlyActivity() {
    final showings =
        _yearlyActivity.fold<double>(0, (s, d) => s + d.laValue);
    final clients =
        _yearlyActivity.fold<double>(0, (s, d) => s + d.baValue);
    final avg = showings / _yearlyActivity.length;
    return _darkCard(
      title: '全年活跃',
      child: Column(
        children: [
          MlsDualLineChart(
            data: _yearlyActivity,
            height: 190,
            line1Color: MlsColors.chartPurple,
            line2Color: MlsColors.chartOrange,
            line1Label: '带看',
            line2Label: '新增客户',
            highlightHighLow: true,
          ),
          const SizedBox(height: 10),
          _metricRow3('累计带看', '${showings.round()}', '累计客户',
              '${clients.round()}', '月均', avg.toStringAsFixed(1)),
        ],
      ),
    );
  }

  // ── Card 4: 转化漏斗 (dark) ──
  Widget _card4Funnel() {
    final stages = _funnelTab == 0 ? _funnelStages90 : _funnelStagesAll;
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
          _metricRow3('带看率', '75%', '成交率', '33%', '整体', '25%'),
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
    return _darkCard(
      title: '房源分布',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MlsDonutChart(
            segments: _donutSegments,
            size: 130,
            strokeWidth: 14,
            showLegend: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _donutSegments
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
      child: Row(
        children: [
          Expanded(
            child: MlsMedalInline(
              icon: LucideIcons.key,
              iconCount: 3,
              iconColor: MlsColors.primary,
              label: '协作积分',
              valueText: '247',
              subtitle: '资深 · ↑12',
              dark: true,
            ),
          ),
          Container(width: 1, height: 56, color: Colors.white10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('信用评分',
                    style: MlsTypography.monoLabel
                        .copyWith(color: Colors.white38)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('4.6',
                        style: MlsTypography.monoLarge
                            .copyWith(color: Colors.white)),
                    const SizedBox(width: 8),
                    MlsProgressRing(
                      percent: 0.92,
                      size: 36,
                      strokeWidth: 4,
                      valueColor: MlsColors.warning,
                      animate: false,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (_) => const Icon(LucideIcons.star,
                            size: 10, color: MlsColors.warning)),
                    const SizedBox(width: 6),
                    Text('12 次评价',
                        style: MlsTypography.monoTinyLabel
                            .copyWith(color: Colors.white38)),
                  ],
                ),
              ],
            ),
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

  // ── helpers ──

  Widget _darkCard(
      {String? title, Widget? trailing, required Widget child}) {
    return MlsCard(
      variant: MlsCardVariant.dark,
      backgroundColor: MlsColors.bgCardDark,
      borderColor: MlsColors.borderCard,
      borderWidth: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
