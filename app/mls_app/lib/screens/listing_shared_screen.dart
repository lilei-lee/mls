import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/listing_filters.dart';
import '../services/api_client.dart';
import '../widgets/base64_image.dart';
import '../widgets/filter_sheet.dart';

/// 共享房源库(搜索 + 排序 + 筛选 + Tab:全部/今日新,匿名浏览)
///
/// Day 9 重构:
/// - 顶部加 Tab:"全部 / 今日新"(默认"全部")
/// - 原路由参数 `?new_today=1` 仍支持(兼容旧工作台入口),会默认选中"今日新" Tab
///
/// Day 16 增量:
/// - 卡片标题右侧显示我的申请状态标签("已申请" / "已通过")
/// - 已 pending/approved 的房,"申请带客"按钮置灰,提示已有协作
class ListingSharedScreen extends StatefulWidget {
  /// true = 初始选中"今日新" Tab(兼容旧路由)
  /// false = 初始选中"全部" Tab(默认)
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

  String _sortKey = 'newest';

  ListingFilters _filters = ListingFilters.empty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.newTodayOnly ? 1 : 0,
    );
    _tabController.addListener(() {
      // Tab 切换时触发重建(显示对应的 header 和空态文案)
      if (_tabController.indexIsChanging ||
          _tabController.index != _tabController.previousIndex) {
        setState(() {});
      }
    });
    _searchController.addListener(() {
      if (_keyword != _searchController.text.trim()) {
        setState(() {
          _keyword = _searchController.text.trim();
        });
      }
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
    final response = await ApiClient.instance.dio.get(
      '/listings/shared',
      queryParameters: newToday ? {'new_today': '1'} : null,
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
    }
  }

  List<Map<String, dynamic>> _processItems(List<Map<String, dynamic>> items) {
    final filtered = items.where((item) {
      if (_keyword.isNotEmpty) {
        final community = (item['community'] ?? '').toString();
        if (!community.contains(_keyword)) return false;
      }
      if (!_filters.matches(item)) return false;
      return true;
    }).toList();

    switch (_sortKey) {
      case 'price_desc':
        filtered.sort((a, b) =>
            (b['price_wan'] as num).compareTo(a['price_wan'] as num));
        break;
      case 'price_asc':
        filtered.sort((a, b) =>
            (a['price_wan'] as num).compareTo(b['price_wan'] as num));
        break;
      case 'area_desc':
        filtered.sort((a, b) =>
            (b['area_sqm'] as num).compareTo(a['area_sqm'] as num));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTextColor =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: appBarTextColor, fontSize: 16),
                cursorColor: appBarTextColor,
                decoration: InputDecoration(
                  hintText: '搜索小区名',
                  hintStyle:
                      TextStyle(color: appBarTextColor.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              )
            : const Text('共享房源库'),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.close : Icons.search),
            tooltip: _searchMode ? '关闭搜索' : '搜索',
            onPressed: _toggleSearch,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: '筛选',
                onPressed: _openFilterSheet,
              ),
              if (_filters.isActive)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (value) {
              setState(() {
                _sortKey = value;
              });
            },
            itemBuilder: (ctx) => [
              _sortMenuItem('newest', '最新上架', Icons.schedule),
              _sortMenuItem('price_desc', '价格高→低', Icons.arrow_downward),
              _sortMenuItem('price_asc', '价格低→高', Icons.arrow_upward),
              _sortMenuItem('area_desc', '面积大→小', Icons.aspect_ratio),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '今日新'),
          ],
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

  Widget _buildListView(Future<Map<String, dynamic>> future,
      {required bool isTodayTab}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }

        final data = snapshot.data!;
        final allItems = (data['items'] as List).cast<Map<String, dynamic>>();
        final processed = _processItems(allItems);

        if (processed.isEmpty) {
          return _buildEmpty(allItems.isEmpty, isTodayTab: isTodayTab);
        }

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: processed.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _headerText(processed.length, allItems.length,
                            isTodayTab: isTodayTab),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      _anonymousBadge(),
                      if (_filters.isActive) _filterBadge(),
                    ],
                  ),
                );
              }
              return _SharedListingCard(
                item: processed[index - 1],
                onAfterApply: _refresh, // Day 16:申请成功后刷新,标签随之更新
              );
            },
          ),
        );
      },
    );
  }

  Widget _anonymousBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '匿名浏览',
        style: TextStyle(color: Colors.blue, fontSize: 11),
      ),
    );
  }

  Widget _filterBadge() {
    return GestureDetector(
      onTap: () {
        setState(() => _filters = ListingFilters.empty);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '已筛选 ${_filters.activeDimensionCount} 项',
              style: const TextStyle(color: Colors.orange, fontSize: 11),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.close, color: Colors.orange, size: 12),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(
      String value, String label, IconData icon) {
    final selected = _sortKey == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? Colors.blue : Colors.grey),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.blue : null,
              fontWeight: selected ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  String _headerText(int shown, int total, {required bool isTodayTab}) {
    if (_keyword.isNotEmpty || _filters.isActive) {
      return '找到 $shown 套(共 $total 套)';
    }
    if (isTodayTab) {
      return '今日新增 $shown 套';
    }
    return '共 $shown 套在售房源';
  }

  Widget _buildEmpty(bool totallyEmpty, {required bool isTodayTab}) {
    String title;
    String? subtitle;
    if (totallyEmpty) {
      if (isTodayTab) {
        title = '今日暂无新房源';
        subtitle = '同行还没录入今天的新房源,稍后再来看看';
      } else {
        title = '暂无其他经纪人的共享房源';
        subtitle = '当其他经纪人录入房源后,这里会展示';
      }
    } else if (_filters.isActive || _keyword.isNotEmpty) {
      title = '没有符合条件的房源';
      subtitle = '试试调整筛选条件或搜索关键字';
    } else {
      title = '没有房源';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTodayTab ? Icons.new_releases_outlined : Icons.home_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败:$err', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('重试')),
        ],
      ),
    );
  }
}

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

  /// Day 16:我对这房的申请状态(后端返字段)
  /// - 'pending' / 'approved' / null
  String? get _myRequestStatus => item['my_request_status'] as String?;

  bool get _hasMyRequest => _myRequestStatus != null;

  Widget? _buildMyRequestBadge() {
    if (_myRequestStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 10, color: Colors.orange),
            SizedBox(width: 2),
            Text('已申请',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    if (_myRequestStatus == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 10, color: Colors.green),
            SizedBox(width: 2),
            Text('已通过',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return null;
  }

  void _onTapApply(BuildContext context, Map<String, dynamic> snapshot) async {
    // Day 16:已有 pending/approved 时拦截 + 提示
    if (_myRequestStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已对这套房发起过申请,等待 LA 审批中(可在协作 Tab 跟进)'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (_myRequestStatus == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已对这套房通过审批,请到协作 Tab 推进带看'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await context.push<bool>(
      '/showing-request/new',
      extra: {
        'listing_id': item['listing_id'],
        'snapshot': snapshot,
      },
    );
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
    final remarks = (item['remarks'] ?? '').toString();
    final createdAt = item['created_at'] as String?;
    final cover = item['cover_thumbnail'] as String?;
    final photoCount = (item['photo_count'] as num?)?.toInt() ?? 0;
    final bonusYuan = (item['bonus_yuan'] as num?)?.toInt() ?? 0;

    final unitPrice = area > 0 ? (priceWan * 10000 / area).round() : 0;

    final myRequestBadge = _buildMyRequestBadge();
    final snapshot = {
      'community': community,
      'building': building,
      'unit': unit,
      'room_no': roomNo,
      'layout': layout,
      'area_sqm': area,
      'price_wan': priceWan,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Base64Image(
                        dataUrl: cover,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (photoCount > 0)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                '$photoCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (bonusYuan > 0)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_offer,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                '奖¥$bonusYuan',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (district.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                district,
                                style: const TextStyle(
                                    color: Colors.blue, fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              '$community $building-$unit-$roomNo',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (myRequestBadge != null) ...[
                            const SizedBox(width: 4),
                            myRequestBadge,
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: [
                          _tag(layout, bold: true),
                          _tag('${area.toStringAsFixed(0)}㎡'),
                          if (floor != null && totalFloor != null)
                            _tag('$floor/$totalFloor层'),
                          if (orientation.isNotEmpty) _tag(orientation),
                        ],
                      ),
                      if (remarks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          remarks,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '¥${priceWan.toStringAsFixed(priceWan == priceWan.roundToDouble() ? 0 : 1)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Text('万',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 11)),
                                ],
                              ),
                              if (unitPrice > 0)
                                Text(
                                  '$unitPrice 元/㎡',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 10),
                                ),
                            ],
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => _onTapApply(context, snapshot),
                            icon: Icon(
                              _hasMyRequest
                                  ? Icons.check
                                  : Icons.person_add,
                              size: 14,
                            ),
                            label: Text(
                              _myRequestStatus == 'pending'
                                  ? '已申请'
                                  : _myRequestStatus == 'approved'
                                      ? '已通过'
                                      : '申请带客',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _myRequestStatus == 'pending'
                                  ? Colors.orange
                                  : _myRequestStatus == 'approved'
                                      ? Colors.green
                                      : null,
                              side: BorderSide(
                                color: _myRequestStatus == 'pending'
                                    ? Colors.orange
                                    : _myRequestStatus == 'approved'
                                        ? Colors.green
                                        : Colors.grey.shade400,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _relativeTime(createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}