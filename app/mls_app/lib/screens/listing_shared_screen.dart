import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/listing_filters.dart';
import '../services/api_client.dart';
import '../widgets/base64_image.dart';
import '../widgets/filter_sheet.dart';

/// 共享房源库 V2.2: 5 行卡片 + 5 类筛选 + 筛选状态指示
class ListingSharedScreen extends StatefulWidget {
  final bool newTodayOnly;
  const ListingSharedScreen({super.key, this.newTodayOnly = false});
  @override State<ListingSharedScreen> createState() => _ListingSharedScreenState();
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
    _tabController.dispose(); _searchController.dispose();
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
      if (!_searchMode) { _searchController.clear(); _keyword = ''; }
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
    // V2.2 #2 段 5: 排序由服务端处理(除 default 外)
    return filtered;
  }

  /// V2.2: 构建筛选已选芯片行
  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];
    if (_filters.salePoints.isNotEmpty) {
      chips.add(_filterChip('卖点(${_filters.salePoints.length})', 'sale_points'));
    }
    if (_filters.objectiveFeatures.isNotEmpty) {
      chips.add(_filterChip('格局(${_filters.objectiveFeatures.length})', 'objective_features'));
    }
    if (_filters.decoration != null) {
      chips.add(_filterChip('装修:${_filters.decoration}', 'decoration'));
    }
    if (_filters.heatingType != null) {
      chips.add(_filterChip('供暖:${_filters.heatingType}', 'heating_type'));
    }
    if (_filters.bldYearMin != null || _filters.bldYearMax != null) {
      final s = _filters.bldYearMin != null ? _filters.bldYearMin.toString() : '1990';
      final e = _filters.bldYearMax != null ? _filters.bldYearMax.toString() : '2026';
      chips.add(_filterChip('楼龄:$s-$e', 'bld_year'));
    }
    if (_filters.orientation != null) {
      chips.add(_filterChip('朝向:${_filters.orientation}', 'orientation'));
    }
    if (_filters.houseStructure != null) {
      chips.add(_filterChip('结构:${_filters.houseStructure}', 'house_structure'));
    }
    return chips;
  }

  Widget _filterChip(String label, String dimension) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () => _removeFilter(dimension),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.blue.shade50,
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
                style: TextStyle(color: appBarTextColor, fontSize: 16),
                cursorColor: appBarTextColor,
                decoration: InputDecoration(
                  hintText: '搜索小区名',
                  hintStyle: TextStyle(color: appBarTextColor.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              )
            : const Text('共享房源库'),
        actions: [
          IconButton(icon: Icon(_searchMode ? Icons.close : Icons.search), tooltip: _searchMode ? '关闭搜索' : '搜索', onPressed: _toggleSearch),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.tune), tooltip: '筛选', onPressed: _openFilterSheet),
              if (_filters.isActive)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${_filters.activeDimensionCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort), tooltip: '排序',
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
              _sortMenuItem('default', '默认排序', Icons.list),
              _sortMenuItem('price_desc', '总价高→低', Icons.arrow_downward),
              _sortMenuItem('price_asc', '总价低→高', Icons.arrow_upward),
              _sortMenuItem('unit_price_asc', '单价低→高', Icons.attach_money),
              _sortMenuItem('area_desc', '面积大→小', Icons.aspect_ratio),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: '刷新', onPressed: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
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
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      _anonymousBadge(),
                    ]),
                    if (filterChips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 4, runSpacing: 4, children: filterChips),
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
    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: const Text('匿名浏览', style: TextStyle(color: Colors.blue, fontSize: 11)),
  );

  PopupMenuItem<String> _sortMenuItem(String value, String label, IconData icon) {
    final sel = _filters.sort == value;
    return PopupMenuItem<String>(value: value, child: Row(children: [
      Icon(icon, size: 18, color: sel ? Colors.blue : Colors.grey),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: sel ? Colors.blue : null, fontWeight: sel ? FontWeight.bold : null)),
    ]));
  }

  String _headerText(int shown, int total, {required bool isTodayTab}) {
    if (_keyword.isNotEmpty || _filters.isActive) return '找到 $shown 套(共 $total 套)';
    if (isTodayTab) return '今日新增 $shown 套';
    return '共 $shown 套房源';
  }

  Widget _buildEmpty(bool totallyEmpty, {required bool isTodayTab}) {
    String title; String? subtitle;
    if (totallyEmpty) {
      title = isTodayTab ? '今日暂无新房源' : '暂无其他经纪人的共享房源';
      subtitle = isTodayTab ? '同行还没录入今天的新房源,稍后再来看看' : '当其他经纪人录入房源后,这里会展示';
    } else if (_filters.isActive || _keyword.isNotEmpty) {
      title = '没有符合条件的房源'; subtitle = '试试调整筛选条件或搜索关键字';
    } else { title = '没有房源'; }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(isTodayTab ? Icons.new_releases_outlined : Icons.home_outlined, size: 80, color: Colors.grey),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
      if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13))],
    ]));
  }

  Widget _buildError(String err) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 60, color: Colors.red),
    const SizedBox(height: 16),
    Text('加载失败:$err', style: const TextStyle(color: Colors.red)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _refresh, child: const Text('重试')),
  ]));
}

// ═══════════════════════ V2.2 5 行卡片 ═══════════════════════

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
    } catch (_) { return ''; }
  }

  String? get _myRequestStatus => item['my_request_status'] as String?;
  bool get _hasMyRequest => _myRequestStatus != null;

  Widget? _buildListingStatusBadge() {
    final status = (item['status'] ?? '').toString();
    String label; Color color;
    switch (status) {
      case 'on_sale': label = '在售'; color = Colors.green; break;
      case 'deposit_paid': label = '定金已付'; color = Colors.blue; break;
      case 'transaction_ongoing': label = '成交进行中'; color = Colors.orange; break;
      case 'sold': label = '已成交'; color = Colors.grey; break;
      default: return null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget? _buildMyRequestBadge() {
    if (_myRequestStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_empty, size: 10, color: Colors.orange), SizedBox(width: 2),
          Text('已申请', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      );
    }
    if (_myRequestStatus == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, size: 10, color: Colors.green), SizedBox(width: 2),
          Text('已通过', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return null;
  }

  /// V2.2: 收集最多 3 个标签(sale_points + objective_features)
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
      'listing_id': item['listing_id'], 'snapshot': snapshot,
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

    final myRequestBadge = _buildMyRequestBadge();
    final listingStatusBadge = _buildListingStatusBadge();
    final snapshot = {
      'community': community, 'building': building, 'unit': unit, 'room_no': roomNo,
      'layout': layout, 'area_sqm': area, 'price_wan': priceWan,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 封面图
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Base64Image(dataUrl: cover, width: 110, height: 110, fit: BoxFit.cover),
                ),
                if (photoCount > 0)
                  Positioned(right: 4, bottom: 4, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.image, size: 10, color: Colors.white), const SizedBox(width: 2),
                      Text('$photoCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ]),
                  )),
                if (bonusYuan > 0)
                  Positioned(left: 4, top: 4, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(3)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_offer, size: 10, color: Colors.white), const SizedBox(width: 2),
                      Text('奖¥$bonusYuan', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  )),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Row 1: 地址 ──
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (district.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
                        child: Text(district, style: const TextStyle(color: Colors.blue, fontSize: 10)),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text('$community $building-$unit-$roomNo',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (listingStatusBadge != null) ...[const SizedBox(width: 4), listingStatusBadge],
                    if (myRequestBadge != null) ...[const SizedBox(width: 4), myRequestBadge],
                  ]),
                  const SizedBox(height: 4),

                  // ── Row 2: 户型 · 面积 · 楼层 ──
                  Row(children: [
                    Text(layout, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text('${area.toStringAsFixed(0)}㎡', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (floor != null && totalFloor != null) ...[
                      const SizedBox(width: 8),
                      Text('$floor/$totalFloor层', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    if (orientation.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(orientation, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ]),
                  const SizedBox(height: 4),

                  // ── Row 3: 标签 chips ──
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        ...tags.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)),
                            child: Text(t, style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                          ),
                        )),
                      ]),
                    ),

                  // ── Row 4: public_remarks 截断 ──
                  if (publicRemarks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        publicRemarks.length > 50 ? '${publicRemarks.substring(0, 50)}...' : publicRemarks,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  // ── Row 5: 价格 + 单价 + 时间 ──
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text('¥${priceWan.toStringAsFixed(priceWan == priceWan.roundToDouble() ? 0 : 1)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(width: 2),
                        const Text('万', style: TextStyle(color: Colors.red, fontSize: 11)),
                      ]),
                      if (unitPrice > 0)
                        Text('$unitPrice 元/㎡', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ]),
                    if (createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(_relativeTime(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _onTapApply(context, snapshot),
                      icon: Icon(_hasMyRequest ? Icons.check : Icons.person_add, size: 14),
                      label: Text(
                        _myRequestStatus == 'pending' ? '已申请' : _myRequestStatus == 'approved' ? '已通过' : '申请带客',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _myRequestStatus == 'pending' ? Colors.orange : _myRequestStatus == 'approved' ? Colors.green : null,
                        side: BorderSide(color: _myRequestStatus == 'pending' ? Colors.orange : _myRequestStatus == 'approved' ? Colors.green : Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

