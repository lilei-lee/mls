import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/membership.dart';
import '../services/membership_service.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_radius.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_setting_tile.dart';

/// 我的 / 设置
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notif = true;
  String _name = '';
  Membership? _membership;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMembership();
  }

  Future<void> _loadProfile() async {
    const storage = FlutterSecureStorage();
    final n = await storage.read(key: 'name');
    if (mounted) setState(() => _name = n ?? '经纪人');
  }

  Future<void> _loadMembership() async {
    try {
      final m = await MembershipService.instance.getMembership();
      if (mounted) setState(() => _membership = m);
    } catch (_) {
      // 会员状态非关键,拉取失败静默(页面其余照常)
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出', style: TextStyle(color: MlsColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await const FlutterSecureStorage().deleteAll();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _buildHero()),
                SliverToBoxAdapter(child: _buildProgressCard()),
                SliverToBoxAdapter(child: _buildSettingsSection()),
                SliverToBoxAdapter(child: const SizedBox(height: 80)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(gradient: MlsColors.panelDark),
      child: Column(children: [
        MlsNavBar(title: '我的', dark: true, right: Icon(Icons.settings, size: 20, color: Colors.white.withValues(alpha: 0.7))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2)),
              child: MlsAvatar(name: _name, size: 60),
            ),
            const SizedBox(height: 10),
            Text(_name.isNotEmpty ? _name : '经纪人', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.medal, size: 13, color: MlsColors.gold),
              const SizedBox(width: 4),
              Text('黄金经纪人', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 12, color: MlsColors.goldLight)),
            ]),
            const SizedBox(height: 2),
            Text('张家口 MLS · 桥东片区 · ID 200318', style: TextStyle(fontFamily: MlsTypography.monoFamily, fontFamilyFallback: MlsTypography.monoFallback, fontSize: 10, color: MlsColors.textOnDarkSubtle, letterSpacing: 0.3)),
            const SizedBox(height: 16),
            // 三栏统计
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                borderRadius: MlsRadius.card,
                border: Border.all(color: MlsColors.borderOnDark, width: 0.5),
              ),
              child: IntrinsicHeight(
                child: Row(children: [
                  _statCell('累计成交', '23', MlsColors.textOnDark),
                  Container(width: 0.5, color: MlsColors.borderOnDark),
                  _statCell('信誉等级', 'A', MlsColors.goldLight),
                  Container(width: 0.5, color: MlsColors.borderOnDark),
                  _statCell('守约率', '100%', MlsColors.success),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statCell(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontFamily: MlsTypography.monoFamily, fontFamilyFallback: MlsTypography.monoFallback, fontSize: 22, fontWeight: FontWeight.w700, color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: MlsColors.textOnDarkSubtle)),
      ]),
    );
  }

  Widget _buildProgressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: MlsCard(
        variant: MlsCardVariant.gold,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(LucideIcons.trendingUp, size: 18, color: MlsColors.gold),
            const SizedBox(width: 8),
            Text('距『白金经纪人』还差 3 单', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 13, fontWeight: FontWeight.w600, color: MlsColors.goldTextDark)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: 0.75, backgroundColor: MlsColors.goldBgStart, color: MlsColors.gold, minHeight: 6),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('本季 9/12 单', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: MlsColors.goldTextMid)),
            const Spacer(),
            Text('升级享 +5% 协作分成', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: MlsColors.goldTextMid)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 会员过期只读横幅(仅收费期且已过期时显示)
        if (_membership?.readOnly == true) ...[
          _buildReadOnlyBanner(),
          const SizedBox(height: 14),
        ],
        // 业务
        MlsCard(padding: EdgeInsets.zero, child: Column(children: [
          MlsSettingTile.link(icon: LucideIcons.home, iconBg: MlsColors.primaryBg, iconFg: MlsColors.primary, title: '我的房源', subtitle: '12 套', onTap: () => context.push('/listings/mine')),
          _divider(),
          MlsSettingTile.link(icon: LucideIcons.users, iconBg: MlsColors.successBg, iconFg: MlsColors.success, title: '我的客户', subtitle: '8 位', onTap: () => context.push('/home?tab=3')),
          _divider(),
          MlsSettingTile.link(icon: Icons.handshake, iconBg: MlsColors.warningBg, iconFg: MlsColors.warning, title: '协作记录', subtitle: '5 进行中', onTap: () => context.push('/home?tab=2')),
          _divider(),
          MlsSettingTile.link(icon: LucideIcons.badgeDollarSign, iconBg: MlsColors.goldBgStart, iconFg: MlsColors.gold, title: '奖金结算', subtitle: '查看明细', onTap: () => context.push('/settlements/pending-my')),
        ])),
        const SizedBox(height: 14),
        // 账户
        MlsCard(padding: EdgeInsets.zero, child: Column(children: [
          MlsSettingTile.link(
            icon: LucideIcons.crown,
            iconBg: MlsColors.goldBgStart,
            iconFg: MlsColors.gold,
            title: '会员状态',
            subtitle: _membership?.badgeText ?? '加载中',
            onTap: _loadMembership,
          ),
          _divider(),
          MlsSettingTile(icon: LucideIcons.shieldCheck, iconBg: MlsColors.successBg, iconFg: MlsColors.success, title: '实名认证', badgeText: '已认证', badgeColor: MlsColors.success),
          _divider(),
          MlsSettingTile.switchTile(icon: LucideIcons.bell, iconBg: MlsColors.primaryBg, iconFg: MlsColors.primary, title: '消息通知', value: _notif, onChanged: (v) => setState(() => _notif = v)),
          _divider(),
          MlsSettingTile.link(icon: LucideIcons.lock, iconBg: const Color(0x0D0F172A), iconFg: MlsColors.textSecondary, title: '修改密码', onTap: () => context.push('/change-password')),
          _divider(),
          MlsSettingTile.link(icon: LucideIcons.helpCircle, iconBg: const Color(0x0D0F172A), iconFg: MlsColors.textSecondary, title: '帮助与反馈', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('帮助与反馈')));
          }),
        ])),
        const SizedBox(height: 20),
        // 退出登录
        Center(
          child: MlsPrimaryButton(text: '退出登录', variant: MlsButtonVariant.text, onPressed: _logout),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text('张家口 MLS · v2.3.0', style: TextStyle(fontFamily: MlsTypography.monoFamily, fontFamilyFallback: MlsTypography.monoFallback, fontSize: 10, color: MlsColors.textTertiary, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _buildReadOnlyBanner() {
    final m = _membership;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MlsColors.dangerBg,
        borderRadius: MlsRadius.card,
        border: Border.all(color: MlsColors.danger.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(children: [
        Icon(LucideIcons.alertTriangle, size: 18, color: MlsColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('会员已过期 · 当前为只读模式',
                style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 13, fontWeight: FontWeight.w600, color: MlsColors.danger)),
            const SizedBox(height: 2),
            Text(m?.subtitle ?? '续费后恢复全部功能',
                style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: MlsColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 0.5, color: MlsColors.borderLight);
}
