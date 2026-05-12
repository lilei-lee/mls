import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_radius.dart';
import '../theme/mls_typography.dart';
import '../theme/mls_animations.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_status_badge.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_section_header.dart';
import '../widgets/mls/mls_segmented_control.dart';

/// 批次 2 基础组件预览页 V1
///
/// 入口: 跑 flutter run --target=lib/main_preview.dart (见 main_preview.dart)
///
/// 不影响主 App, 不挂主路由。所有 6 个基础组件按 section 排列, 真机看效果。
class MlsPreviewScreen extends StatefulWidget {
  const MlsPreviewScreen({super.key});

  @override
  State<MlsPreviewScreen> createState() => _MlsPreviewScreenState();
}

class _MlsPreviewScreenState extends State<MlsPreviewScreen> {
  String _segPillSel = '本月';
  String _segUnderlineSel = '买方协作';

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
              // ========= 头部 =========
              MlsIn(
                delayIndex: 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MLS 组件预览', style: MlsTypography.greeting),
                      const SizedBox(height: 4),
                      Text(
                        '批次 2 · 6 个基础组件 · ${DateTime.now().toString().substring(0, 10)}',
                        style: MlsTypography.caption1,
                      ),
                    ],
                  ),
                ),
              ),

              // ========= 1. MlsCard =========
              _previewSection(
                index: 1,
                title: '1. MlsCard · 立体卡片',
                children: [
                  MlsCard(
                    child: Text('primary · 白渐变 + 中等阴影 (默认)',
                        style: MlsTypography.body1),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    variant: MlsCardVariant.elevated,
                    child: Text('elevated · 强阴影焦点卡片',
                        style: MlsTypography.body1),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    variant: MlsCardVariant.gold,
                    child: Text('gold · 暖橙金 (奖金区)',
                        style: MlsTypography.body1.copyWith(
                          color: MlsColors.goldTextDark,
                        )),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    variant: MlsCardVariant.dark,
                    child: Text('dark · 深色面板 (反作弊基石)',
                        style: MlsTypography.body1.copyWith(
                          color: MlsColors.textOnDark,
                        )),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    variant: MlsCardVariant.hero,
                    padding: const EdgeInsets.all(16),
                    child: Text('hero · 蓝渐变 (Hero Today 大卡片)',
                        style: MlsTypography.body1.copyWith(
                          color: Colors.white,
                          fontWeight: MlsTypography.medium,
                        )),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    variant: MlsCardVariant.flat,
                    child: Text('flat · 轻阴影列表项',
                        style: MlsTypography.body1),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    onTap: () => _toast(context, '卡片被点击'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('可点击卡片 (按下有 scale 0.98 反馈)',
                              style: MlsTypography.body1),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14, color: MlsColors.textTertiary),
                      ],
                    ),
                  ),
                ],
              ),

              // ========= 2. MlsAvatar =========
              _previewSection(
                index: 2,
                title: '2. MlsAvatar · 渐变头像',
                children: [
                  MlsCard(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: const [
                        MlsAvatar(name: '李红'),
                        MlsAvatar(name: '王明'),
                        MlsAvatar(name: '周丽'),
                        MlsAvatar(name: '陈强'),
                        MlsAvatar(name: '杨敏'),
                        MlsAvatar(
                          name: '李红',
                          onlineStatus: MlsOnlineStatus.online,
                        ),
                        MlsAvatar(
                          name: '陈强',
                          onlineStatus: MlsOnlineStatus.away,
                        ),
                        MlsAvatar(name: '张三', size: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('协作伙伴 stack:',
                            style: MlsTypography.cardSubtitle),
                        const SizedBox(height: 10),
                        MlsAvatarStack(
                          names: const ['李红', '王明', '周丽', '陈强', '杨敏'],
                          onlineMap: const {
                            '李红': MlsOnlineStatus.online,
                            '王明': MlsOnlineStatus.online,
                            '周丽': MlsOnlineStatus.online,
                            '陈强': MlsOnlineStatus.away,
                            '杨敏': MlsOnlineStatus.online,
                          },
                          moreCount: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ========= 3. MlsStatusBadge =========
              _previewSection(
                index: 3,
                title: '3. MlsStatusBadge · 状态徽章',
                children: [
                  MlsCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        MlsStatusBadge(text: '已确认', variant: MlsBadgeVariant.info),
                        MlsStatusBadge(text: '在线', variant: MlsBadgeVariant.success, showDot: true),
                        MlsStatusBadge(text: '即将到期', variant: MlsBadgeVariant.warning),
                        MlsStatusBadge(text: '紧急', variant: MlsBadgeVariant.danger),
                        MlsStatusBadge(text: '单月新高 PR', variant: MlsBadgeVariant.gold),
                        MlsStatusBadge(text: '已结单', variant: MlsBadgeVariant.neutral),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('dense + mono (大写技术标签):',
                            style: MlsTypography.cardSubtitle),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            MlsStatusBadge(
                              text: 'PRIORITY · HIGH',
                              variant: MlsBadgeVariant.danger,
                              size: MlsBadgeSize.dense,
                              mono: true,
                            ),
                            MlsStatusBadge(
                              text: 'SCHEDULED · 15:00',
                              variant: MlsBadgeVariant.info,
                              size: MlsBadgeSize.dense,
                              mono: true,
                            ),
                            MlsStatusBadge(
                              text: 'PR · ¥3,200',
                              variant: MlsBadgeVariant.gold,
                              size: MlsBadgeSize.dense,
                              mono: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    variant: MlsCardVariant.dark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('onDark (反作弊基石内嵌):',
                            style: MlsTypography.cardSubtitle.copyWith(
                              color: MlsColors.textOnDarkMuted,
                            )),
                        const SizedBox(height: 10),
                        const MlsStatusBadge(
                          text: 'SECURED',
                          variant: MlsBadgeVariant.onDark,
                          size: MlsBadgeSize.dense,
                          mono: true,
                          showDot: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ========= 4. MlsPrimaryButton =========
              _previewSection(
                index: 4,
                title: '4. MlsPrimaryButton · 主按钮',
                children: [
                  MlsCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MlsPrimaryButton(
                          text: '立即处理',
                          trailingIcon: Icons.arrow_forward,
                          onPressed: () => _toast(context, 'primary'),
                        ),
                        MlsPrimaryButton(
                          text: '独立录入 · 提交',
                          variant: MlsButtonVariant.dark,
                          leadingIcon: Icons.lock_outline,
                          onPressed: () => _toast(context, 'dark'),
                        ),
                        MlsPrimaryButton(
                          text: '立即处理',
                          variant: MlsButtonVariant.danger,
                          trailingIcon: Icons.arrow_forward,
                          onPressed: () => _toast(context, 'danger'),
                        ),
                        MlsPrimaryButton(
                          text: '立即准备',
                          variant: MlsButtonVariant.outline,
                          trailingIcon: Icons.arrow_forward,
                          onPressed: () => _toast(context, 'outline'),
                        ),
                        MlsPrimaryButton(
                          text: '取消',
                          variant: MlsButtonVariant.secondary,
                          onPressed: () => _toast(context, 'secondary'),
                        ),
                        MlsPrimaryButton(
                          text: '查看更多',
                          variant: MlsButtonVariant.text,
                          trailingIcon: Icons.chevron_right,
                          onPressed: () => _toast(context, 'text'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  MlsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('禁用 / loading / fullWidth:',
                            style: MlsTypography.cardSubtitle),
                        const SizedBox(height: 10),
                        MlsPrimaryButton(
                          text: '禁用态',
                          fullWidth: true,
                          onPressed: null,
                        ),
                        const SizedBox(height: 8),
                        MlsPrimaryButton(
                          text: '提交中...',
                          fullWidth: true,
                          loading: true,
                          onPressed: () {},
                        ),
                        const SizedBox(height: 8),
                        MlsPrimaryButton(
                          text: '尺寸 small',
                          size: MlsButtonSize.small,
                          variant: MlsButtonVariant.secondary,
                          onPressed: () => _toast(context, 'small'),
                        ),
                        const SizedBox(height: 8),
                        MlsPrimaryButton(
                          text: '尺寸 large · fullWidth',
                          size: MlsButtonSize.large,
                          fullWidth: true,
                          onPressed: () => _toast(context, 'large'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ========= 5. MlsSectionHeader =========
              _previewSection(
                index: 5,
                title: '5. MlsSectionHeader · 区块标题',
                children: [
                  MlsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MlsSectionHeader(
                          title: '待办',
                          badge: '2',
                          trailingLabel: 'PENDING',
                          padding: EdgeInsets.zero,
                          bottomSpacing: 4,
                        ),
                        Text('— 此例: 标题旁红色徽章, 右侧 mono 大写标签',
                            style: MlsTypography.caption1),
                        const SizedBox(height: 16),
                        const MlsSectionHeader(
                          title: '协作中',
                          leadingIcon: Icons.people_outline,
                          trailingLabel: 'SEE ALL ↗',
                          padding: EdgeInsets.zero,
                          bottomSpacing: 4,
                        ),
                        Text('— 此例: 标题左侧 icon, 右侧文字链接',
                            style: MlsTypography.caption1),
                        const SizedBox(height: 16),
                        MlsSectionHeader(
                          title: '本月战绩',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('共 3 单',
                                  style: MlsTypography.monoLabel),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 10, color: MlsColors.textTertiary),
                            ],
                          ),
                          padding: EdgeInsets.zero,
                          bottomSpacing: 4,
                        ),
                        Text('— 此例: trailing 完全自定义 widget',
                            style: MlsTypography.caption1),
                      ],
                    ),
                  ),
                ],
              ),

              // ========= 6. MlsSegmentedControl =========
              _previewSection(
                index: 6,
                title: '6. MlsSegmentedControl · 分段切换',
                children: [
                  MlsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('pill · 灰底白滑块 (仪表盘时间维度):',
                            style: MlsTypography.cardSubtitle),
                        const SizedBox(height: 8),
                        MlsSegmentedControl<String>(
                          values: const ['本月', '本季', '今年'],
                          selected: _segPillSel,
                          onChanged: (v) =>
                              setState(() => _segPillSel = v),
                        ),
                        const SizedBox(height: 16),
                        Text('underline · 下划线 (协作 Tab 角色切换):',
                            style: MlsTypography.cardSubtitle),
                        const SizedBox(height: 4),
                        MlsSegmentedControl<String>(
                          values: const ['买方协作', '卖方协作'],
                          selected: _segUnderlineSel,
                          onChanged: (v) =>
                              setState(() => _segUnderlineSel = v),
                          variant: MlsSegmentedVariant.underline,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ========= 收尾 =========
              const SizedBox(height: 24),
              MlsIn(
                delayIndex: 7,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: MlsColors.successBg,
                      borderRadius: MlsRadius.badge,
                    ),
                    child: Text(
                      '批次 2 · 6 / 6 组件已加载',
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

  /// 一个 section: 标题 + 内容卡片群; 整体 MlsIn 入场, 错峰 80ms
  Widget _previewSection({
    required int index,
    required String title,
    required List<Widget> children,
  }) {
    return MlsIn(
      delayIndex: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Text(title,
                  style: MlsTypography.cardTitleLg.copyWith(
                    color: MlsColors.textPrimary,
                  )),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1500),
      ));
  }
}
