import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/listing_filters.dart';
import '../services/api_client.dart';
import '../widgets/base64_image.dart';
import '../widgets/filter_sheet.dart';
import '../components/app_empty.dart';
import '../components/app_card.dart';

/// 共享房源库 V2.4: 5 行卡片 + 5 类筛选 + v2.0 设计系统
class ListingSharedScreen extends StatefulWidget {
  final bool newTodayOnly;
  const ListingSharedScreen({super.key, this.newTodayOnly = false});
  @override
  State<ListingSharedScreen> createState() => _ListingSharedScreenState();
}

class _ListingSharedScreenState extends State<ListingSharedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _allListFuture;
  late Future<Map<String, dynamic>> _todayListFuture;

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  ListingFilters _filters = ListingFilters.empty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.newTodayOnly ? 1 : 0);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _tabController.previousIndex) setState(() {});
    });
    _searchController.addListener(() {
      if (_keyword != _searchController.text.trim()) setState(() => _keyword = _searchController.text.trim());
    });
    _allListFuture = _fetchList(newToday: false);
    _todayListFuture = _fetchList(newToday: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchList({required bool newToday}) async {
    final qp = <String, String>{};
    if (newToday) qp['new_today'] = '1';
    qp.addAll(_filters.toQueryParams());
    final response = await ApiClient.instance.dio.get(
      '/listings/shared',
      queryParameters: qp.isNotEmpty ? qp : null,
    );
    return response.data as Map<String, dynamic>;
  }

  void _refresh() {
    setState(() {
      _allListFuture = _fetchList(newToday: false);
      _todayListFuture = _fetchList(newToday: true);
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchController.clear();
        _keyword = '';
      }
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<ListingFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _refresh();
    }
  }

  void _removeFilter(String dimension) {
    setState(() {
      _filters = ListingFilters(
        districts: _filters.districts,
        roomCounts: _filters.roomCounts,
        minArea: _filters.minArea, maxArea: _filters.maxArea,
        minPrice: _filters.minPrice, maxPrice: _filters.maxPrice,
        salePoints: dimension == 'sale_points' ? const {} : _filters.salePoints,
        objectiveFeatures: dimension == 'objective_features' ? const {} : _filters.objectiveFeatures,
        decoration: dimension == 'decoration' ? null : _filters.decoration,
        heatingType: dimension == 'heating_type' ? null : _filters.heatingType,
        bldYearMin: dimension == 'bld_year' ? null : _filters.bldYearMin,
        bldYearMax: dimension == 'bld_year' ? null : _filters.bldYearMax,
        orientation: dimension == 'orientation' ? null : _filters.orientation,
        houseStructure: dimension == 'house_structure' ? null : _filters.houseStructure,
      );
    });
    _refresh();
  }

  List<Map<String, dynamic>> _processItems(List<Map<String, dynamic>> items) {
    final filtered = items.where((item) {
      if (_keyword.isNotEmpty) {
        final community = (item['community'] ?? '').toString();
        if (!community.contains(_keyword)) return false;
      }
      if (_filters.isActive && !_filters.matches(item)) return false;
      return true;
    }).toList();
    return filtered;
  }

  /// V2.4: 已选筛选 Pill 行
  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];
    if (_filters.salePoints.isNotEmpty) chips.add(_filterChip('卖点(${_filters.salePoints.length})', 'sale_points'));
    if (_filters.objectiveFeatures.isNotEmpty) chips.add(_filterChip('格局(${_filters.objectiveFeatures.length})', 'objective_features'));
    if (_filters.decoration != null) chips.add(_filterChip('装修:${_filters.decoration}', 'decoration'));
    if (_filters.heatingType != null) chips.add(_filterChip('供暖:${_filters.heatingType}', 'heating_type'));
    if (_filters.bldYearMin != null || _filters.bldYearMax != null) {
      final s = _filters.bldYearMin?.toString() ?? '1990';
      final e = _filters.bldYearMax?.toString() ?? '2026';
      chips.add(_filterChip('楼龄:$s-$e', 'bld_year'));
    }
    if (_filters.orientation != null) chips.add(_filterChip('朝向:${_filters.orientation}', 'orientation'));
    if (_filters.houseStructure != null) chips.add(_filterChip('结构:${_filters.houseStructure}', 'house_structure'));
    return chips;
  }

  /// V2.4: Pill 圆角 999 + Primary 50 底 + Lucide.x 关闭
  Widget _filterChip(String label, String dimension) {
    return Material(
      color: AppTheme.primary50,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _removeFilter(dimension),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: AppTheme.fontCaption, color: AppTheme.primary500, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(LucideIcons.x, size: 12, color: AppTheme.primary500),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTextColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                controller: _searchController, autofocus: true,
                style: TextStyle(color: appBarTextColor, fontSize: AppTheme.fontSectionTitle),
                cursorColor: appBarTextColor,
                decoration: InputDecoration(
                  hintText: '搜索小区名',
                  hintStyle: TextStyle(color: appBarTextColor.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              )
            : const Text('共享房源库'),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? LucideIcons.x : LucideIcons.search, size: 22),
            tooltip: _searchMode ? '关闭搜索' : '搜索',
            onPressed: _toggleSearch,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.slidersHorizontal, size: 22),
                tooltip: '筛选',
                onPressed: _openFilterSheet,
              ),
              if (_filters.isActive)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: AppTheme.warning, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${_filters.activeDimensionCount}',
                          style: const TextStyle(color: Colors.white, fontSize: AppTheme.fontSmall, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.arrowUpDown, size: 22),
            tooltip: '排序',
            onSelected: (value) {
              setState(() {
                _filters = ListingFilters(
                  districts: _filters.districts, roomCounts: _filters.roomCounts,
                  minArea: _filters.minArea, maxArea: _filters.maxArea,
                  minPrice: _filters.minPrice, maxPrice: _filters.maxPrice,
                  salePoints: _filters.salePoints, objectiveFeatures: _filters.objectiveFeatures,
                  decoration: _filters.decoration, heatingType: _filters.heatingType,
                  bldYearMin: _filters.bldYearMin, bldYearMax: _filters.bldYearMax,
                  orientation: _filters.orientation, houseStructure: _filters.houseStructure,
                  sort: value,
                );
              });
              _refresh();
            },
            itemBuilder: (ctx) => [
              _sortMenuItem('default', '默认排序', LucideIcons.list),
              _sortMenuItem('price_desc', '总价高→低', LucideIcons.arrowDown),
              _sortMenuItem('price_asc', '总价低→高', LucideIcons.arrowUp),
              _sortMenuItem('unit_price_asc', '单价低→高', LucideIcons.tag),
              _sortMenuItem('area_desc', '面积大→小', LucideIcons.maximize),
            ],
          ),
          IconButton(icon: const Icon(LucideIcons.refreshCw, size: 22), tooltip: '刷新', onPressed: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: AppTheme.n500,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [Tab(text: '全部'), Tab(text: '今日新')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListView(_allListFuture, isTodayTab: false),
          _buildListView(_todayListFuture, isTodayTab: true),
        ],
      ),
    );
  }

  Widget _buildListView(Future<Map<String, dynamic>> future, {required bool isTodayTab}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _buildError(snapshot.error.toString());

        final data = snapshot.data!;
        final allItems = (data['items'] as List).cast<Map<String, dynamic>>();
        final processed = _processItems(allItems);

        if (processed.isEmpty) return _buildEmpty(allItems.isEmpty, isTodayTab: isTodayTab);

        final filterChips = _buildFilterChips();

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: processed.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(_headerText(processed.length, allItems.length, isTodayTab: isTodayTab),
                          style: TextStyle(color: AppTheme.n500, fontSize: AppTheme.fontBody)),
                      _anonymousBadge(),
                    ]),
                    if (filterChips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: filterChips),
                    ],
                  ]),
                );
              }
              return _SharedListingCard(item: processed[index - 1], onAfterApply: _refresh);
            },
          ),
        );
      },
    );
  }

  Widget _anonymousBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.primary50, borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
        child: Text('匿名浏览', style: TextStyle(color: AppTheme.primary500, fontSize: AppTheme.fontCaption)),
      );

  PopupMenuItem<String> _sortMenuItem(String value, String label, IconData icon) {
    final sel = _filters.sort == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: sel ? AppTheme.primary500 : AppTheme.n500),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: sel ? AppTheme.primary500 : AppTheme.n800, fontWeight: sel ? FontWeight.w600 : null)),
      ]),
    );
  }

  String _headerText(int shown, int total, {required bool isTodayTab}) {
    if (_keyword.isNotEmpty || _filters.isActive) return '找到 $shown 套(共 $total 套)';
    if (isTodayTab) return '今日新增 $shown 套';
    return '共 $shown 套房源';
  }

  Widget _buildEmpty(bool totallyEmpty, {required bool isTodayTab}) {
    String title;
    String? subtitle;
    if (totallyEmpty) {
      title = isTodayTab ? '今日暂无新房源' : '暂无其他经纪人的共享房源';
      subtitle = isTodayTab ? '同行还没录入今天的新房源' : '当其他经纪人录入房源后,这里会展示';
    } else if (_filters.isActive || _keyword.isNotEmpty) {
      title = '没有符合条件的房源';
      subtitle = '试试调整筛选条件或搜索关键字';
    } else {
      title = '没有房源';
      subtitle = null;
    }
    return AppEmpty(
      icon: LucideIcons.inbox,
      title: title,
      subtitle: subtitle,
      actionLabel: (_filters.isActive || _keyword.isNotEmpty) ? '重置筛选' : null,
      onAction: (_filters.isActive || _keyword.isNotEmpty)
          ? () {
              setState(() => _filters = ListingFilters.empty);
              _refresh();
            }
          : null,
    );
  }

  Widget _buildError(String err) => AppEmpty(
        icon: LucideIcons.alertTriangle,
        title: '加载失败',
        subtitle: err,
        actionLabel: '重试',
        onAction: _refresh,
      );
}

// ═══════════════════════ V2.4 房源卡片 (AppCard.base + Primary 价格 + Lucide) ═══════════════════════

class _SharedListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onAfterApply;
  const _SharedListingCard({required this.item, this.onAfterApply});

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final t = DateTime.parse(iso);
      final diff = DateTime.now().difference(t);
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} 个月前';
      if (diff.inDays > 0) return '${diff.inDays} 天前';
      if (diff.inHours > 0) return '${diff.inHours} 小时前';
      if (diff.inMinutes > 0) return '${diff.inMinutes} 分钟前';
      return '刚刚';
    } catch (_) {
      return '';
    }
  }

  String? get _myRequestStatus => item['my_request_status'] as String?;

  Widget? _buildListingStatusBadge() {
    final status = (item['status'] ?? '').toString();
    String label;
    Color color;
    switch (status) {
      case 'on_sale':
        label = '在售';
        color = AppTheme.success;
        break;
      case 'deposit_paid':
        label = '定金已付';
        color = AppTheme.info;
        break;
      case 'transaction_ongoing':
        label = '成交进行中';
        color = AppTheme.warning;
        break;
      case 'sold':
        label = '已成交';
        color = AppTheme.n500;
        break;
      default:
        return null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      child: Text(label, style: TextStyle(color: color, fontSize: AppTheme.fontSmall, fontWeight: FontWeight.w600)),
    );
  }

  Widget? _buildMyRequestBadge() {
    if (_myRequestStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.clock4, size: 10, color: AppTheme.warning),
          const SizedBox(width: 2),
          Text('已申请', style: TextStyle(color: AppTheme.warning, fontSize: AppTheme.fontSmall, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    if (_myRequestStatus == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.checkCircle, size: 10, color: AppTheme.success),
          const SizedBox(width: 2),
          Text('已通过', style: TextStyle(color: AppTheme.success, fontSize: AppTheme.fontSmall, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return null;
  }

  List<String> _collectTags() {
    final tags = <String>[];
    final sp = item['sale_points'];
    if (sp is List) {
      for (final t in sp.cast<String>()) {
        if (tags.length >= 3) break;
        tags.add(t);
      }
    }
    final of = item['objective_features'];
    if (of is List && tags.length < 3) {
      for (final t in of.cast<String>()) {
        if (tags.length >= 3) break;
        tags.add(t);
      }
    }
    return tags;
  }

  void _onTapApply(BuildContext context, Map<String, dynamic> snapshot) async {
    if (_myRequestStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已对这套房发起过申请,等待 LA 审批中(可在协作 Tab 跟进)'), duration: Duration(seconds: 3)),
      );
      return;
    }
    if (_myRequestStatus == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已对这套房通过审批,请到协作 Tab 推进带看'), duration: Duration(seconds: 3)),
      );
      return;
    }
    final result = await context.push<bool>('/showing-request/new', extra: {
      'listing_id': item['listing_id'],
      'snapshot': snapshot,
    });
    if (result == true) onAfterApply?.call();
  }

  @override
  Widget build(BuildContext context) {
    final district = (item['district'] ?? '').toString();
    final community = item['community'] ?? '';
    final building = item['building'] ?? '';
    final unit = item['unit'] ?? '';
    final roomNo = item['room_no'] ?? '';
    final layout = item['layout'] ?? '';
    final area = (item['area_sqm'] as num?)?.toDouble() ?? 0;
    final floor = item['floor'];
    final totalFloor = item['total_floor'];
    final orientation = item['orientation'] ?? '';
    final priceWan = (item['price_wan'] as num?)?.toDouble() ?? 0;
    final publicRemarks = (item['public_remarks'] ?? '').toString();
    final createdAt = item['created_at'] as String?;
    final cover = item['cover_thumbnail'] as String?;
    final photoCount = (item['photo_count'] as num?)?.toInt() ?? 0;
    final bonusYuan = (item['bonus_yuan'] as num?)?.toInt() ?? 0;
    final unitPrice = area > 0 ? (priceWan * 10000 / area).round() : 0;
    final tags = _collectTags();
    final hotKeywords = {'急售', '诚售', '诚意', '低价', '必看', '满五', '业主诚意'};
    final isHot = item['sale_points'] is List && (item['sale_points'] as List).cast<String>().any((t) => hotKeywords.contains(t));

    final myRequestBadge = _buildMyRequestBadge();
    final listingStatusBadge = _buildListingStatusBadge();
    final snapshot = {
      'community': community,
      'building': building,
      'unit': unit,
      'room_no': roomNo,
      'layout': layout,
      'area_sqm': area,
      'price_wan': priceWan,
    };

    final cardChild = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图 + 角标
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Base64Image(dataUrl: cover, width: 110, height: 110, fit: BoxFit.cover),
              ),
              if (photoCount > 0)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.image, size: 10, color: Colors.white),
                      const SizedBox(width: 2),
                      Text('$photoCount', style: const TextStyle(color: Colors.white, fontSize: AppTheme.fontSmall)),
                    ]),
                  ),
                ),
              if (bonusYuan > 0)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.gold500, borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.tag, size: 10, color: Colors.white),
                      const SizedBox(width: 2),
                      Text('奖¥$bonusYuan', style: const TextStyle(color: Colors.white, fontSize: AppTheme.fontSmall, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: 必看好房 + 小区名 + 状态徽标 ──
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (isHot) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFDC1414), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                      child: const Text('必看好房', style: TextStyle(color: Colors.white, fontSize: AppTheme.fontSmall, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text('$community $building-$unit-$roomNo',
                      style: TextStyle(fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.w700, color: AppTheme.n900),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (listingStatusBadge != null) ...[const SizedBox(width: 4), listingStatusBadge],
                  if (myRequestBadge != null) ...[const SizedBox(width: 4), myRequestBadge],
                ]),
                // 地址小一行
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    const Icon(LucideIcons.mapPin, size: 12, color: AppTheme.n500),
                    const SizedBox(width: 2),
                    Text('$district · $community', style: TextStyle(fontSize: AppTheme.fontCaption, color: AppTheme.n500)),
                  ]),
                ),
                const SizedBox(height: 4),

                // ── Row 2: 户型 | 面积 | 楼层 | 朝向 ──
                Text(
                  [layout, '${area.toStringAsFixed(0)}㎡',
                   if (floor != null && totalFloor != null) '$floor/$totalFloor层',
                   if (orientation.isNotEmpty) orientation,
                  ].join(' | '),
                  style: TextStyle(fontSize: AppTheme.fontCaption, color: AppTheme.n700),
                ),
                const SizedBox(height: 4),

                // ── Row 3: 标签 chips ──
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: AppTheme.n50, borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                                child: Text(t, style: TextStyle(fontSize: AppTheme.fontSmall, color: AppTheme.n700)),
                              ))
                          .toList(),
                    ),
                  ),

                // ── Row 4: public_remarks 截断 ──
                if (publicRemarks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      publicRemarks.length > 50 ? '${publicRemarks.substring(0, 50)}...' : publicRemarks,
                      style: TextStyle(color: AppTheme.n500, fontSize: AppTheme.fontCaption),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // ── Row 5: 价格 + 单价 + 时间 + 申请按钮 ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '¥${priceWan.toStringAsFixed(priceWan == priceWan.roundToDouble() ? 0 : 1)}',
                              style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800,
                                color: Color(0xFFDC1414),
                                fontFeatures: [FontFeature.tabularFigures()],
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text('万', style: TextStyle(color: AppTheme.n900, fontSize: AppTheme.fontBody, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (unitPrice > 0)
                          Text('$unitPrice 元/㎡', style: TextStyle(color: AppTheme.n500, fontSize: AppTheme.fontSmall)),
                      ],
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(_relativeTime(createdAt), style: TextStyle(color: AppTheme.n500, fontSize: AppTheme.fontSmall)),
                    ],
                    const Spacer(),
                    Material(
                      color: _myRequestStatus == 'pending'
                          ? AppTheme.warning
                          : _myRequestStatus == 'approved'
                              ? AppTheme.success
                              : const Color(0xFF2B7FFF),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _onTapApply(context, snapshot),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: Text(
                            _myRequestStatus == 'pending' ? '已申请' : _myRequestStatus == 'approved' ? '已通过' : '申请带客',
                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard.base(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/listing/${item['listing_id']}'),
        child: cardChild,
      ),
    );
  }
}