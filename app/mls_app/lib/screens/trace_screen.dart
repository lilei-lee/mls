import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_radius.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_progress_stepper.dart';
import '../widgets/mls/mls_trace_item.dart';

/// 留痕时间线 + 成交确认签字 (产品灵魂)
///
/// 双方独立留痕、互不可改、链路自动结算。
class TraceScreen extends StatefulWidget {
  /// 房源名
  final String listingName;

  /// 协作伙伴名
  final String partnerName;

  /// 伙伴角色 (BA/LA)
  final String partnerRole;

  /// 客户名
  final String customerName;

  /// 当前进度 (0-based index into trace steps)
  final int currentStep;

  /// LA 姓名
  final String laName;

  const TraceScreen({
    super.key,
    required this.listingName,
    required this.partnerName,
    required this.partnerRole,
    required this.customerName,
    this.currentStep = 3,
    this.laName = '张三',
  });

  @override
  State<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen>
    with SingleTickerProviderStateMixin {
  bool _signed = false;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 3600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  static const _steps = [
    MlsStepData(label: '申请'),
    MlsStepData(label: '同意'),
    MlsStepData(label: '带看'),
    MlsStepData(label: '发起'),
    MlsStepData(label: '录入', badge: '5'),
  ];

  List<({String who, TraceSide side, IconData icon, String title, String detail, String time, String? hash, bool done, bool current, bool future})> get _traceEvents => [
        (
          who: widget.partnerName,
          side: TraceSide.ba,
          icon: LucideIcons.send,
          title: '发起带看申请',
          detail: '申请带${widget.customerName}看「${widget.listingName}」',
          time: 'TODAY · 09:12:04',
          hash: '0x7f3a…91c',
          done: true,
          current: false,
          future: false,
        ),
        (
          who: widget.laName,
          side: TraceSide.la,
          icon: LucideIcons.check,
          title: '同意协作申请',
          detail: '已确认 BA 身份 · 授权带看',
          time: 'TODAY · 09:40:18',
          hash: '0x2b8e…4af',
          done: true,
          current: false,
          future: false,
        ),
        (
          who: widget.partnerName,
          side: TraceSide.ba,
          icon: LucideIcons.userCheck,
          title: '完成实地带看',
          detail: '带看 108㎡ · 客户二次咨询 · 已上传现场留痕',
          time: 'TODAY · 15:06:33',
          hash: '0xc1d0…7e2',
          done: true,
          current: false,
          future: false,
        ),
        (
          who: widget.laName,
          side: TraceSide.la,
          icon: LucideIcons.fileText,
          title: '发起成交确认',
          detail: '成交价 ¥218万 · 等待双方独立签字',
          time: 'TODAY · 16:20:09',
          hash: '0x9a45…0bb',
          done: true,
          current: true,
          future: false,
        ),
        (
          who: '双方',
          side: TraceSide.sign,
          icon: LucideIcons.pencil,
          title: '成交确认签字',
          detail: '双方各自独立签字后链路闭合，奖金自动结算',
          time: '待你签字',
          hash: null,
          done: false,
          current: false,
          future: true,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final events = _traceEvents;

    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ═══ 深色 Hero 区 ═══
                SliverToBoxAdapter(
                  child: _buildHeroSection(),
                ),

                // ═══ 链路留痕 ═══
                SliverToBoxAdapter(
                  child: _buildTimelineSection(events),
                ),

                // ═══ 签字面板 ═══
                SliverToBoxAdapter(
                  child: _buildSignaturePanel(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // ═══ sticky 底部操作栏 ═══
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      decoration: const BoxDecoration(gradient: MlsColors.panelDark),
      child: Stack(
        children: [
          // ── 扫描线动画 ──
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 80,
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (_, __) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0x1F86EFAC), // rgba(134,239,172,.12)
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Column(
            children: [
              // ── NavBar (dark) ──
              MlsNavBar(
                title: '成交确认 · 留痕',
                dark: true,
                right: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x1A22C55E), // 10% green
                    borderRadius: BorderRadius.circular(MlsRadius.sm),
                    border: Border.all(
                      color: const Color(0x4D22C55E), // 30% green
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'SECURED',
                    style: TextStyle(
                      fontFamily: MlsTypography.monoFamily,
                      fontFamilyFallback: MlsTypography.monoFallback,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: const Color(0xFF86EFAC),
                    ),
                  ),
                ),
              ),

              // ── 房源名 + Avatars ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.listingName,
                      style: TextStyle(
                        fontFamilyFallback: MlsTypography.sansFallback,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 26,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              MlsAvatar(name: widget.laName, size: 26, borderWidth: 2, borderColor: const Color(0xFF1E293B)),
                              Positioned(
                                left: 18,
                                child: MlsAvatar(name: widget.partnerName, size: 26, borderWidth: 2, borderColor: const Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${widget.laName} LA · ${widget.partnerName} ${widget.partnerRole} · ${widget.customerName}',
                            style: TextStyle(
                              fontFamilyFallback: MlsTypography.sansFallback,
                              fontSize: 12,
                              color: MlsColors.textOnDarkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── ProgressStepper 外壳 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF), // 5% white
                    borderRadius: BorderRadius.circular(MlsRadius.xl2),
                    border: Border.all(color: MlsColors.borderOnDark, width: 0.5),
                  ),
                  child: MlsProgressStepper(
                    steps: _steps,
                    currentIndex: widget.currentStep.clamp(0, 4),
                    doneColor: MlsColors.success,
                    currentColor: MlsColors.primary,
                    futureColor: const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(List<dynamic> events) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──
          Row(
            children: [
              Icon(Icons.timeline, size: 16, color: MlsColors.textSecondary),
              const SizedBox(width: 8),
              Text('链路留痕', style: MlsTypography.sectionTitle),
              const Spacer(),
              Text(
                'IMMUTABLE · 互不可改',
                style: MlsTypography.monoLabel,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 5 个 TraceItem ──
          ...List.generate(events.length, (i) {
            final e = events[i];
            return MlsTraceItem(
              side: e.side,
              icon: e.icon,
              title: e.title,
              detail: e.detail,
              time: e.time,
              hash: e.hash,
              who: e.who,
              done: e.done,
              current: e.current,
              future: e.future,
              isLast: i == events.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSignaturePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: MlsCard(
        variant: MlsCardVariant.dark,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题行 ──
            Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 18, color: const Color(0xFF86EFAC)),
                const SizedBox(width: 8),
                Text(
                  '双方独立签字 · 反作弊基石',
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MlsColors.textOnDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 2 列签字格 ──
            Row(
              children: [
                Expanded(child: _signSlot(name: widget.laName, role: 'LA', signed: true)),
                const SizedBox(width: 10),
                Expanded(child: _signSlot(name: widget.partnerName, role: widget.partnerRole, signed: _signed)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _signSlot({required String name, required String role, required bool signed}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(MlsRadius.xl),
        border: Border.all(
          color: signed ? const Color(0x6622C55E) : MlsColors.borderOnDark,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MlsAvatar(name: name, size: 24),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamilyFallback: MlsTypography.sansFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MlsColors.textOnDark,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(
                        fontFamily: MlsTypography.monoFamily,
                        fontFamilyFallback: MlsTypography.monoFallback,
                        fontSize: 8.5,
                        letterSpacing: 1,
                        color: MlsColors.textOnDarkSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                signed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 13,
                color: signed ? const Color(0xFF86EFAC) : MlsColors.textOnDarkSubtle,
              ),
              const SizedBox(width: 4),
              Text(
                signed ? 'SIGNED' : 'PENDING',
                style: TextStyle(
                  fontFamily: MlsTypography.monoFamily,
                  fontFamilyFallback: MlsTypography.monoFallback,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: signed ? const Color(0xFF86EFAC) : MlsColors.textOnDarkSubtle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MlsColors.bgPageEnd.withValues(alpha: 0.88),
        border: const Border(top: BorderSide(color: MlsColors.borderLight, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: _signed
            ? MlsPrimaryButton(
                text: '已签字 · 奖金自动结算中',
                variant: MlsButtonVariant.primary,
                size: MlsButtonSize.large,
                leadingIcon: Icons.check,
                fullWidth: true,
                onPressed: null, // disabled
              )
            : MlsPrimaryButton(
                text: '确认签字 · 留痕闭合',
                variant: MlsButtonVariant.dark,
                size: MlsButtonSize.large,
                leadingIcon: LucideIcons.pencil,
                fullWidth: true,
                onPressed: () => setState(() => _signed = true),
              ),
      ),
    );
  }
}
