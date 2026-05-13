import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_metric_cell.dart';
import '../widgets/mls/mls_progress_ring.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工作仪表盘')),
      floatingActionButton: const SizedBox.shrink(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MlsCard(
            variant: MlsCardVariant.gold,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('本月奖金 · 距目标', style: MlsTypography.monoLabel),
              const SizedBox(height: 12),
              Row(children: [
                MlsProgressRing(
                  percent: 0.56,
                  size: 100,
                  strokeWidth: 9,
                  valueColor: MlsColors.gold,
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('56%', style: TextStyle(
                      fontFamily: MlsTypography.monoFamily,
                      fontSize: 22, fontWeight: MlsTypography.bold,
                      color: MlsColors.goldTextDark,
                    )),
                    Text('已达成', style: MlsTypography.caption1),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('¥8,400', style: TextStyle(
                    fontFamily: MlsTypography.monoFamily,
                    fontSize: 32, fontWeight: MlsTypography.bold,
                    color: MlsColors.goldTextDark,
                  )),
                  const SizedBox(height: 4),
                  Text('还差 ¥6,600 达成 ¥15,000', style: MlsTypography.body2),
                  const SizedBox(height: 8),
                  Text('↑ ¥1,200 vs 上月', style: MlsTypography.body2.copyWith(color: MlsColors.success)),
                ])),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          MlsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('本月业绩', style: MlsTypography.cardTitleLg),
              const SizedBox(height: 14),
              const Row(children: [
                Expanded(child: MlsMetricCell(
                  label: '成交单数', value: '03', suffix: '↑1',
                  valueColor: MlsColors.success, padding: EdgeInsets.zero,
                )),
                Expanded(child: MlsMetricCell(
                  label: '带看次数', value: '12',
                  trailing: MlsMiniBars(values: [2, 4, 3, 5, 4, 4, 1]),
                  padding: EdgeInsets.zero,
                )),
              ]),
              const SizedBox(height: 18),
              const Row(children: [
                Expanded(child: MlsMetricCell(
                  label: '新增客户', value: '08',
                  trailing: MlsSparkline(points: [3, 5, 4, 6, 5, 7]),
                  padding: EdgeInsets.zero,
                )),
                Expanded(child: MlsMetricCell(
                  label: '协作积分', value: '247', suffix: '↑12',
                  valueColor: MlsColors.primary, padding: EdgeInsets.zero,
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          MlsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('房源状态分布', style: MlsTypography.cardTitleLg),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: MlsMetricCell(
                  label: '在售', value: '12', valueColor: MlsColors.primary,
                  padding: EdgeInsets.zero,
                )),
                Expanded(child: MlsMetricCell(
                  label: '到期', value: '02', valueColor: MlsColors.warning,
                  padding: EdgeInsets.zero,
                )),
                Expanded(child: MlsMetricCell(
                  label: '已下架', value: '03', valueColor: MlsColors.textSecondary,
                  padding: EdgeInsets.zero,
                )),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
