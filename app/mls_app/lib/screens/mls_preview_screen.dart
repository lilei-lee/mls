import 'package:flutter/material.dart';
import '../theme/mls_animations.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_radius.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_status_badge.dart';
import '../widgets/mls/mls_hero_today.dart';
import '../widgets/mls/mls_metric_cell.dart';
import '../widgets/mls/mls_progress_ring.dart';
import '../widgets/mls/mls_progress_stepper.dart';
import '../widgets/mls/mls_encrypted_panel.dart';
import '../widgets/mls/mls_money_input.dart';
import '../widgets/mls/mls_countdown_clock.dart';

/// 批次 3 专用组件预览页 V2
///
/// 入口: 跑 flutter run --target=lib/main_preview.dart
///
/// 不影响主 App, 不挂主路由。
/// 这次的预览页相比 V1 更接近真实业务页面 (Hero / 4-metric panel / 反作弊基石 / 进度链),
/// 是验收"视觉规范是否能拼出 mockup 的关键钩子"的核心环节。
class MlsPreviewScreen extends StatefulWidget {
  const MlsPreviewScreen({super.key});

  @override
  State<MlsPreviewScreen> createState() => _MlsPreviewScreenState();
}

class _MlsPreviewScreenState extends State<MlsPreviewScreen> {
  late final DateTime _todayShowingTarget;
  int _moneyValue = 0;

  @override
  void initState() {
    super.initState();
    // 倒计时假数据: 3小时28分钟之后
    _todayShowingTarget =
        DateTime.now().add(const Duration(hours: 3, minutes: 28, seconds: 13));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: Container(
        decoration: const BoxDecoration(gradient: MlsColors.pageBg),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildHeader(),

              // ============ 1. Hero Today ============
              _section(
                index: 1,
                title: '1. MlsHeroToday · 工作台焦点大卡',
                description: '蓝色 hero 渐变 + 倒计时秒数闪烁 + 协作头像 + CTA',
                child: MlsHeroToday(
                  topLabel: 'TODAY · 15:00',
                  subtitle: '今日带看 · 与李红协同',
                  countdownTarget: _todayShowingTarget,
                  title: '万达华府 · 3室朝南',
                  description: '108㎡ · 客户王先生 · 已二次咨询',
                  collaborators: const ['李红', '王先生'],
                  ctaText: '立即准备',
                  onCtaPressed: () => _toast('立即准备'),
                ),
              ),

              // ============ 2. Countdown 单独 ============
              _section(
                index: 2,
                title: '2. MlsCountdownClock · 倒计时',
                description: '秒数 mls-tick 闪烁强化活体感',
                child: MlsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('默认形态:', style: MlsTypography.cardSubtitle),
                      const SizedBox(height: 8),
                      MlsCountdownClock(target: _todayShowingTarget),
                      const SizedBox(height: 14),
                      Text('短形态 (compact):',
                          style: MlsTypography.cardSubtitle),
                      const SizedBox(height: 8),
                      MlsCountdownClock(
                        target: _todayShowingTarget,
                        compact: true,
                        textStyle: MlsTypography.countdown.copyWith(
                          fontSize: 18,
                          color: MlsColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ============ 3. Metric Cell 三种辅助视觉 ============
              _section(
                index: 3,
                title: '3. MlsMetricCell · 数据格',
                description: '一格一 metric, 配 sparkline / mini bars / progress bar',
                child: MlsCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: const MlsMetricCell(
                              label: '待办',
                              value: '02',
                              suffix: '紧急',
                              valueColor: MlsColors.danger,
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 80,
                            color: MlsColors.borderLight,
                          ),
                          Expanded(
                            child: MlsMetricCell(
                              label: '协作活跃',
                              value: '07',
                              suffix: '↑ 2',
                              trailing: MlsSparkline(
                                points: const [3, 5, 4, 6, 5, 4, 7],
                                color: MlsColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                          height: 0.5, color: MlsColors.borderLight),
                      Row(
                        children: [
                          Expanded(
                            child: MlsMetricCell(
                              label: '本月奖金',
                              value: '¥8,400',
                              suffix: '已结算',
                              valueColor: MlsColors.gold,
                              valueFontSize: 20,
                              trailing: const MlsProgressBar(
                                percent: 0.56,
                                color: MlsColors.gold,
                              ),
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 100,
                            color: MlsColors.borderLight,
                          ),
                          Expanded(
                            child: MlsMetricCell(
                              label: '本周带看',
                              value: '04',
                              trailing: MlsMiniBars(
                                values: const [2, 4, 3, 5, 4, 4, 1],
                                color: MlsColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ============ 4. Progress Ring 双形态 ============
              _section(
                index: 4,
                title: '4. MlsProgressRing · 环形进度',
                description: '入场动画 stroke-dashoffset 0 → 目标值',
                child: MlsCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          MlsProgressRing(
                            percent: 0.56,
                            size: 88,
                            strokeWidth: 8,
                            valueColor: MlsColors.gold,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('56%',
                                    style: TextStyle(
                                      fontFamily: MlsTypography.monoFamily,
                                      fontFamilyFallback: MlsTypography.monoFallback,
                                      fontSize: 22,
                                      fontWeight: MlsTypography.semibold,
                                      color: MlsColors.goldTextDark,
                                      height: 1,
                                    )),
                                Text('已达成',
                                    style: TextStyle(
                                      fontFamilyFallback: MlsTypography.sansFallback,
                                      fontSize: 10,
                                      color: MlsColors.goldTextDark,
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('本月奖金 · 56%',
                              style: MlsTypography.cardSubtitle),
                        ],
                      ),
                      Column(
                        children: [
                          MlsProgressRing(
                            percent: 0.83,
                            size: 88,
                            strokeWidth: 8,
                            valueColor: MlsColors.primary,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('83',
                                    style: TextStyle(
                                      fontFamily: MlsTypography.monoFamily,
                                      fontFamilyFallback: MlsTypography.monoFallback,
                                      fontSize: 22,
                                      fontWeight: MlsTypography.semibold,
                                      color: MlsColors.primary,
                                      height: 1,
                                    )),
                                Text('信用分',
                                    style: TextStyle(
                                      fontFamilyFallback: MlsTypography.sansFallback,
                                      fontSize: 10,
                                      color: MlsColors.primary,
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('协作信用 · 83',
                              style: MlsTypography.cardSubtitle),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ============ 5. Progress Stepper ============
              _section(
                index: 5,
                title: '5. MlsProgressStepper · 进度链',
                description: '5 节点流程, 当前节点 pulse, 通往当前的最后一段虚线 (独立断开)',
                child: MlsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('成交确认链 (当前第 5 节点 · 录入):',
                          style: MlsTypography.cardSubtitle),
                      const SizedBox(height: 14),
                      const MlsProgressStepper(
                        steps: [
                          MlsStepData(label: '申请'),
                          MlsStepData(label: '同意'),
                          MlsStepData(label: '带看'),
                          MlsStepData(label: '发起'),
                          MlsStepData(label: '录入', badge: '5'),
                        ],
                        currentIndex: 4,
                      ),
                      const SizedBox(height: 18),
                      Text('对照: 当前第 3 节点 · 带看:',
                          style: MlsTypography.cardSubtitle),
                      const SizedBox(height: 14),
                      const MlsProgressStepper(
                        steps: [
                          MlsStepData(label: '申请'),
                          MlsStepData(label: '同意'),
                          MlsStepData(label: '带看', badge: '3'),
                          MlsStepData(label: '发起'),
                          MlsStepData(label: '录入'),
                        ],
                        currentIndex: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // ============ 6. Encrypted Panel (核心创新) ============
              _section(
                index: 6,
                title: '6. MlsEncryptedPanel · 反作弊基石加密面板',
                description: '深色面板 + 蓝色扫描线 + ▓▓▓ 遮罩字段 + SECURED 徽章',
                child: const MlsEncryptedPanel(
                  submitterName: '李红',
                  submitterRole: 'BA',
                  visibleFields: {
                    '客户姓氏': '王先生',
                    '付款方式': '商业贷款',
                  },
                  maskedFields: [
                    MlsEncryptedField(label: '成交价', maskLength: 6),
                    MlsEncryptedField(label: '成交日期', maskLength: 8),
                  ],
                ),
              ),

              // ============ 7. Money Input 双形态 ============
              _section(
                index: 7,
                title: '7. MlsMoneyInput · 价格输入框',
                description: '千分位实时格式化 + 万元换算徽章 + "请勿填万元"警告',
                child: Column(
                  children: [
                    MlsCard(
                      child: MlsMoneyInput(
                        label: '我的成交价 (元)',
                        placeholder: '例 1,236,000',
                        onChanged: (yuan) =>
                            setState(() => _moneyValue = yuan),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_moneyValue > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '当前回调值: $_moneyValue 元',
                          style: MlsTypography.caption1.copyWith(
                            color: MlsColors.primary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        gradient: MlsColors.panelDark,
                        borderRadius: MlsRadius.cardLg,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const MlsMoneyInput(
                        label: '反作弊基石内嵌 · 我的成交价 (元)',
                        placeholder: '例 1,236,000',
                        onDark: true,
                        initialValue: 1236000,
                      ),
                    ),
                  ],
                ),
              ),

              // ============ 收尾 ============
              const SizedBox(height: 16),
              MlsIn(
                delayIndex: 8,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: MlsColors.successBg,
                      borderRadius: MlsRadius.badge,
                    ),
                    child: Text(
                      '批次 3 · 7 / 7 组件已加载',
                      style: MlsTypography.monoBadge.copyWith(
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return MlsIn(
      delayIndex: 0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('MLS 组件预览 V2',
                    style: MlsTypography.greeting),
                const SizedBox(width: 8),
                const MlsStatusBadge(
                  text: 'BATCH · 3',
                  variant: MlsBadgeVariant.gold,
                  size: MlsBadgeSize.dense,
                  mono: true,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '7 个专用组件 · 倒计时/Metric/环/Stepper/反作弊基石/输入框',
              style: MlsTypography.caption1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required int index,
    required String title,
    required String description,
    required Widget child,
  }) {
    return MlsIn(
      delayIndex: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(title,
                  style: MlsTypography.cardTitleLg.copyWith(
                    color: MlsColors.textPrimary,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text(description,
                  style: MlsTypography.caption1.copyWith(
                    color: MlsColors.textTertiary,
                  )),
            ),
            child,
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1500),
      ));
  }
}
