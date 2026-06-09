import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_radius.dart';
import '../theme/mls_typography.dart';
import '../models/listing_showing_summary.dart';
import '../models/qna_thread.dart';
import '../services/api_client.dart';
import '../services/qna_service.dart';
import '../widgets/base64_image.dart';
import '../widgets/mls/mls_avatar.dart';
import '../widgets/mls/mls_card.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_section_header.dart';
import '../widgets/mls/mls_spec_grid.dart';
import '../widgets/mls/mls_status_badge.dart';

/// 房源详情 V3 — hifi 重设计
///
/// 从房源列表推入，展示单套房源全貌、发起协作。
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<List<ListingShowingSummary>?> _showingsFuture;
  bool _listChanged = false;
  String _userRole = '';
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _showingsFuture = _fetchShowingsSummary();
    _loadRole();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final response =
        await ApiClient.instance.dio.get('/listings/${widget.listingId}');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> _loadRole() async {
    const storage = FlutterSecureStorage();
    final r = await storage.read(key: 'role');
    if (mounted) setState(() => _userRole = r ?? '');
  }

  Future<List<ListingShowingSummary>?> _fetchShowingsSummary() async {
    try {
      final r = await ApiClient.instance.dio
          .get('/listings/${widget.listingId}/showings-summary');
      final items = (r.data['items'] as List).cast<Map<String, dynamic>>();
      return items.map((e) => ListingShowingSummary.fromJson(e)).toList();
    } catch (_) {
      return null;
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _fetch();
      _showingsFuture = _fetchShowingsSummary();
      _listChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.pop(_listChanged);
      },
      child: Scaffold(
        backgroundColor: MlsColors.bgPageStart,
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('加载失败:${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }
            final item = snapshot.data!;
            return _buildContent(item);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> item) {
    final photos = ((item['photos'] as List?) ?? []).cast<Map<String, dynamic>>();
    final community = (item['community'] ?? '').toString();
    final building = (item['building'] ?? '').toString();
    final layout = (item['layout'] ?? '').toString();
    final areaSqm = item['area_sqm']?.toString() ?? '';
    final orientation = (item['orientation'] ?? '').toString();
    final floor = (item['floor'] ?? '').toString();
    final totalFloor = (item['total_floor'] ?? '').toString();
    final decoration = (item['decoration'] ?? '').toString();
    final buildYear = (item['build_year'] ?? '').toString();
    final property = (item['property_rights'] ?? '').toString();
    final code = (item['house_code'] ?? item['listing_code'] ?? '').toString();
    final status = (item['status'] ?? 'on_sale').toString();
    final priceWan = item['price_wan']?.toString() ?? '0';
    final statusLabel = _statusLabel(status);
    final statusVariant = _statusVariant(status);
    final ownerName = (item['owner_agent_name'] ?? '').toString();

    // 房源全名
    final listingFullName = building.isNotEmpty
        ? '$community · $building'
        : community.isNotEmpty
            ? community
            : (item['listing_name'] ?? '').toString();

    // 照片占位文本
    final photoLabels = ['客厅', '主卧', '次卧', '厨房', '卫生间', '阳台'];
    final hasRealPhotos = photos.isNotEmpty;
    final effectivePhotoCount = hasRealPhotos ? photos.length : 6;
    final effectivePhotos = hasRealPhotos ? photos : null;
    final currentLabel = hasRealPhotos
        ? '照片 ${_currentPhoto + 1}'
        : photoLabels[_currentPhoto.clamp(0, 5)];

    // 单价计算 (仅当面积和总价都有有效值时显示)
    final area = double.tryParse(areaSqm);
    final price = double.tryParse(priceWan);
    final unitPrice = (area != null && price != null && area > 0)
        ? (price * 10000 / area).round()
        : null;

    // SPEC 数据（过滤空值）
    final specs = <({String k, String v})>[
      if (layout.isNotEmpty) (k: '户型', v: layout),
      if (areaSqm.isNotEmpty) (k: '建筑面积', v: '${areaSqm}㎡'),
      if (orientation.isNotEmpty) (k: '朝向', v: orientation),
      if (floor.isNotEmpty && totalFloor.isNotEmpty) (k: '楼层', v: '$floor / $totalFloor'),
      if (decoration.isNotEmpty) (k: '装修', v: decoration),
      if (buildYear.isNotEmpty) (k: '建成年代', v: buildYear),
      if (property.isNotEmpty) (k: '产权', v: property),
      if (code.isNotEmpty) (k: '挂牌编号', v: code),
    ];

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // ═══ ① NavBar ═══
              SliverToBoxAdapter(
                child: MlsNavBar(
                  title: '房源详情',
                  right: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _navIconButton(LucideIcons.share2, 20),
                      const SizedBox(width: 2),
                      _navIconButton(LucideIcons.bookmark, 20),
                    ],
                  ),
                ),
              ),

              // ═══ ② 照片廊 ═══
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _buildPhotoGallery(
                  effectivePhotos, effectivePhotoCount,
                  statusLabel, statusVariant, currentLabel, photoLabels,
                ),
              )),

              // ═══ ③ 标题/价格块 ═══
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildTitlePrice(listingFullName, priceWan, unitPrice, item),
              )),

              // ═══ ④ SPEC 规格网格 ═══
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildSpecSection(specs),
              )),

              // ═══ ⑤ LA 经纪人卡 ═══
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildAgentCard(ownerName),
              )),

              // ═══ ⑥ 协作 · 带看记录 ═══
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildShowingSection(listingFullName, ownerName),
              )),

              // ═══ ⑦ Q&A ═══
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildQnaSection(item),
              )),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),

        // ═══ sticky 底部操作栏 ═══
        _buildBottomBar(listingFullName, ownerName),
      ],
    );
  }

  // ──── NavBar 图标按钮 ────
  Widget _navIconButton(IconData icon, double size) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(borderRadius: MlsRadius.buttonLg),
        alignment: Alignment.center,
        child: Icon(icon, size: size, color: MlsColors.textSecondary),
      ),
    );
  }

  // ──── 照片廊 ────
  Widget _buildPhotoGallery(
    List<Map<String, dynamic>>? photos,
    int count,
    String statusLabel,
    MlsBadgeVariant statusVariant,
    String currentLabel,
    List<String> labels,
  ) {
    return Column(
      children: [
        // ── 主照片区 ──
        ClipRRect(
          borderRadius: MlsRadius.cardLg,
          child: Container(
            height: 188,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.7, -1),
                end: Alignment(0.7, 1),
                colors: [Color(0xFFE8EDF5), Color(0xFFDCE3EE)],
              ),
            ),
            child: Stack(
              children: [
                // 真实照片或占位
                if (photos != null && photos.isNotEmpty)
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _currentPhoto = i),
                    itemBuilder: (_, i) => Base64Image(
                      dataUrl: photos[i]['data'] as String?,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, size: 40, color: const Color(0x2E0F172A)),
                        const SizedBox(height: 8),
                        Text(
                          '$currentLabel · PHOTO',
                          style: TextStyle(
                            fontFamily: MlsTypography.monoFamily,
                            fontFamilyFallback: MlsTypography.monoFallback,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: const Color(0x4D0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── 状态 badge (左上) ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: MlsStatusBadge(
                    text: statusLabel,
                    variant: statusVariant,
                  ),
                ),

                // ── 计数 (右上) ──
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x800F172A),
                      borderRadius: BorderRadius.circular(MlsRadius.pill),
                    ),
                    child: Text(
                      '${_currentPhoto + 1}/$count',
                      style: TextStyle(
                        fontFamily: MlsTypography.monoFamily,
                        fontFamilyFallback: MlsTypography.monoFallback,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 进度条段 ──
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: List.generate(count, (i) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentPhoto = i),
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      left: i == 0 ? 0 : 3,
                      right: i == count - 1 ? 0 : 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i == _currentPhoto
                          ? MlsColors.primary
                          : const Color(0x1F0F172A),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ──── 标题/价格块 ────
  Widget _buildTitlePrice(String name, String priceWan, int? unitPrice, Map<String, dynamic> item) {
    // 从真实数据中提取特征标签
    final salePoints = (item['sale_points'] as List?)?.cast<String>() ?? [];
    final objectiveFeatures = (item['objective_features'] as List?)?.cast<String>() ?? [];
    final chips = <String>[...salePoints, ...objectiveFeatures];
    // 构造全名

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isNotEmpty ? name : '房源',
          style: TextStyle(
            fontFamilyFallback: MlsTypography.sansFallback,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: MlsColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              priceWan,
              style: TextStyle(
                fontFamily: MlsTypography.monoFamily,
                fontFamilyFallback: MlsTypography.monoFallback,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.5,
                color: MlsColors.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '万',
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MlsColors.primary,
              ),
            ),
            if (unitPrice != null) ...[
              const SizedBox(width: 10),
              Text(
                '单价 ¥$unitPrice/㎡',
                style: MlsTypography.body2,
              ),
            ],
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.take(6).map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x0D0F172A),
                  borderRadius: BorderRadius.circular(MlsRadius.sm),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 11,
                    color: MlsColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ──── SPEC 规格网格 ────
  Widget _buildSpecSection(List<({String k, String v})> specs) {
    if (specs.isEmpty) return const SizedBox.shrink();
    return MlsCard(
      variant: MlsCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPEC · 房源信息',
            style: MlsTypography.monoLabel,
          ),
          const SizedBox(height: 14),
          MlsSpecGrid(items: specs),
        ],
      ),
    );
  }

  // ──── LA 经纪人卡 ────
  Widget _buildAgentCard(String ownerName) {
    return MlsCard(
      child: Row(
        children: [
          MlsAvatar(name: ownerName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ownerName,
                      style: TextStyle(
                        fontFamilyFallback: MlsTypography.sansFallback,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: MlsColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: MlsColors.primaryBg,
                        borderRadius: BorderRadius.circular(MlsRadius.xs),
                      ),
                      child: Text(
                        'LA · 挂牌',
                        style: TextStyle(
                          fontFamily: MlsTypography.monoFamily,
                          fontFamilyFallback: MlsTypography.monoFallback,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: MlsColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '本房源由我挂牌 · 信誉 A · 成交 23',
                  style: MlsTypography.body2,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: MlsColors.primaryBg,
                borderRadius: MlsRadius.buttonLg,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.phone, size: 18, color: MlsColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ──── 协作 · 带看记录 ────
  Widget _buildShowingSection(String listingName, String laName) {
    return FutureBuilder<List<ListingShowingSummary>?>(
      future: _showingsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final summaries = snap.data;
        if (summaries == null || summaries.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlsSectionHeader(title: '协作 · 带看记录', trailingLabel: '0 条'),
              MlsCard(
                variant: MlsCardVariant.flat,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    '暂无带看记录',
                    style: MlsTypography.body2.copyWith(color: MlsColors.textTertiary),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlsSectionHeader(
              title: '协作 · 带看记录',
              trailingLabel: '${summaries.length} 条',
            ),
            ...summaries.map((s) => _buildShowingCard(s, listingName, laName)),
          ],
        );
      },
    );
  }

  Widget _buildShowingCard(ListingShowingSummary summary, String listingName, String laName) {
    const statusLabels = {
      'pending': ('进行中', MlsBadgeVariant.info),
      'approved': ('已通过', MlsBadgeVariant.success),
      'showing_done': ('已带看', MlsBadgeVariant.neutral),
      'transaction_initiated': ('成交发起', MlsBadgeVariant.info),
      'transaction_confirmed': ('已成交', MlsBadgeVariant.success),
      'rejected': ('已拒绝', MlsBadgeVariant.danger),
      'canceled': ('已取消', MlsBadgeVariant.neutral),
    };

    final statusInfo = statusLabels[summary.currentStatus] ?? ('进行中', MlsBadgeVariant.neutral);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MlsCard(
        onTap: () {
          context.push('/trace', extra: {
            'listingName': listingName,
            'partnerName': summary.baName,
            'partnerRole': 'BA',
            'customerName': summary.customerName,
            'currentStep': 3,
            'laName': laName.isNotEmpty ? laName : 'LA',
          });
        },
        child: Row(
          children: [
            MlsAvatar(
              name: summary.baName,
              size: 38,
              onlineStatus: MlsOnlineStatus.online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        summary.baName,
                        style: TextStyle(
                          fontFamilyFallback: MlsTypography.sansFallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MlsColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0x0F0F172A),
                          borderRadius: BorderRadius.circular(MlsRadius.xs),
                        ),
                        child: Text(
                          'BA',
                          style: TextStyle(
                            fontFamily: MlsTypography.monoFamily,
                            fontFamilyFallback: MlsTypography.monoFallback,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: MlsColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      MlsStatusBadge(
                        text: statusInfo.$1,
                        variant: statusInfo.$2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.customerName} · ${summary.createdAt.month}月${summary.createdAt.day}日',
                    style: MlsTypography.body2,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: MlsColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ──── Q&A 问答 ────
  Widget _buildQnaSection(Map<String, dynamic> item) {
    final isOwner = item['_is_owner'] == true;
    return FutureBuilder<QnaListResp>(
      future: QnaService.instance.getList(widget.listingId, limit: 4),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data;
        if (data == null || data.items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlsSectionHeader(title: '问答'),
              MlsCard(
                variant: MlsCardVariant.flat,
                child: SizedBox(
                  height: 80,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.helpCircle, size: 32, color: MlsColors.borderStrong),
                        const SizedBox(height: 8),
                        Text(
                          isOwner ? '等待 BA 提问中' : '看到这套房有疑问?第一个提问吧',
                          style: MlsTypography.body2.copyWith(color: MlsColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final myPending = data.items.where((t) => t.askerIdSelf && t.status == 'pending').length;
        final canAsk = _userRole == 'BA' && !isOwner && myPending < 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlsSectionHeader(title: '问答 (${data.total})'),
            ...data.items.take(3).map((t) => _buildQnaItem(t, isOwner: isOwner)),
            if (_userRole == 'BA' && !isOwner)
              Center(
                child: OutlinedButton.icon(
                  onPressed: canAsk
                      ? () async {
                          await _showAskSheet(context, item['community'] ?? '');
                          _reload();
                        }
                      : null,
                  icon: Icon(LucideIcons.helpCircle, size: 16,
                      color: canAsk ? MlsColors.textPrimary : MlsColors.borderStrong),
                  label: Text(
                    canAsk ? '发起提问' : '已有 $myPending 个问题待回答',
                    style: TextStyle(
                        color: canAsk ? MlsColors.textPrimary : MlsColors.borderStrong),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        canAsk ? MlsColors.textPrimary : MlsColors.borderStrong,
                    side: BorderSide(
                        color: canAsk ? MlsColors.borderStrong : MlsColors.borderLight),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQnaItem(QnaThread t, {required bool isOwner}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.user, size: 14, color: MlsColors.textSecondary),
              const SizedBox(width: 4),
              Text(t.askerName, style: MlsTypography.caption1),
              const Spacer(),
              Text(_fmtTime(t.questionAt),
                  style: MlsTypography.caption1.copyWith(
                      fontSize: 11, color: MlsColors.borderStrong)),
            ],
          ),
          const SizedBox(height: 4),
          Text('问:${t.question}', style: MlsTypography.body2),
          const SizedBox(height: 4),
          if (t.isAnswered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(left: 24),
              decoration: BoxDecoration(
                color: MlsColors.bgPageStart,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.answererName ?? '',
                          style: MlsTypography.caption1
                              .copyWith(color: MlsColors.primary)),
                      const Spacer(),
                      Text(_fmtTime(t.answeredAt),
                          style: MlsTypography.caption1.copyWith(
                              fontSize: 11, color: MlsColors.borderStrong)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(t.answer ?? '', style: MlsTypography.body2),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text('等待回答...',
                        style: MlsTypography.body2.copyWith(
                            color: MlsColors.borderStrong,
                            fontStyle: FontStyle.italic)),
                  ),
                  if (isOwner && t.answererSelf)
                    SizedBox(
                      height: 32,
                      child: TextButton.icon(
                        onPressed: () => _showAnswerSheet(context, t),
                        icon: const Icon(LucideIcons.pencil, size: 14),
                        label: const Text('回答', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: MlsColors.primary),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAskSheet(BuildContext context, String community) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MlsColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('对「$community」提问', style: MlsTypography.sectionTitle),
                const SizedBox(height: 8),
                Text('LA 收到后会尽快回复,问答公开可见',
                    style: MlsTypography.caption1
                        .copyWith(color: MlsColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLength: 200,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '例:满五唯一吗?可议价?能看房吗?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: ctrl.text.trim().isEmpty
                            ? null
                            : () async {
                                try {
                                  await QnaService.instance
                                      .ask(widget.listingId, ctrl.text.trim());
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('提问已发出')),
                                    );
                                    _reload();
                                  }
                                } on QnaException catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(e.message)),
                                    );
                                  }
                                }
                              },
                        child: const Text('提交'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnswerSheet(BuildContext context, QnaThread t) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MlsColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('回答 ${t.askerName} 的提问', style: MlsTypography.sectionTitle),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MlsColors.bgPageStart,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('问:${t.question}',
                      style: MlsTypography.body2.copyWith(color: MlsColors.textPrimary)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLength: 300,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '请客观作答,避免泄露敏感信息',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: ctrl.text.trim().isEmpty
                            ? null
                            : () async {
                                try {
                                  await QnaService.instance
                                      .answer(t.threadId, ctrl.text.trim());
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已回答')),
                                    );
                                    _reload();
                                  }
                                } on QnaException catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(e.message)),
                                    );
                                  }
                                }
                              },
                        child: const Text('回答'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }

  // ──── sticky 底部操作栏 ────
  Widget _buildBottomBar(String listingName, String laName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MlsColors.bgPageEnd.withOpacity(0.88),
        border: const Border(top: BorderSide(color: MlsColors.borderLight, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: MlsPrimaryButton(
                text: '共享到库',
                variant: MlsButtonVariant.secondary,
                leadingIcon: LucideIcons.share2,
                fullWidth: true,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MlsPrimaryButton(
                text: '发起协作',
                variant: MlsButtonVariant.primary,
                leadingIcon: Icons.handshake,
                fullWidth: true,
                onPressed: () {
                  context.push('/trace', extra: {
                    'listingName': listingName,
                    'partnerName': laName.isNotEmpty ? laName : '协作伙伴',
                    'partnerRole': 'BA',
                    'customerName': '',
                    'currentStep': 3,
                    'laName': laName.isNotEmpty ? laName : 'LA',
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──── helpers ────

  String _statusLabel(String status) {
    switch (status) {
      case 'on_sale':
        return '在售';
      case 'deposit_paid':
        return '定金已付';
      case 'transaction_ongoing':
        return '成交进行中';
      case 'sold':
        return '已成交';
      case 'offline':
        return '已下架';
      default:
        return '在售';
    }
  }

  MlsBadgeVariant _statusVariant(String status) {
    switch (status) {
      case 'on_sale':
        return MlsBadgeVariant.success;
      case 'deposit_paid':
        return MlsBadgeVariant.warning;
      case 'transaction_ongoing':
        return MlsBadgeVariant.info;
      case 'sold':
        return MlsBadgeVariant.neutral;
      case 'offline':
        return MlsBadgeVariant.neutral;
      default:
        return MlsBadgeVariant.success;
    }
  }
}
