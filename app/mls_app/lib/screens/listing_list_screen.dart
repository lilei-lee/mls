import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/listing_filters.dart';
import '../services/api_client.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/base64_image.dart';

/// 我的房源列表页(分类 Tab + 搜索 + 排序 + 筛选)
class ListingListScreen extends StatefulWidget {
  const ListingListScreen({super.key});

  @override
  State<ListingListScreen> createState() => _ListingListScreenState();
}

class _ListingListScreenState extends State<ListingListScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _listFuture;
  late TabController _tabController;

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  String _sortKey = 'newest';

  ListingFilters _filters = ListingFilters.empty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _searchController.addListener(() {
      if (_keyword != _searchController.text.trim()) {
        setState(() {
          _keyword = _searchController.text.trim();
        });
      }
    });
    _listFuture = _fetchList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchList() async {
    final response = await ApiClient.instance.dio.get('/listings/mine');
    return response.data as Map<String, dynamic>;
  }

  void _refresh() {
    setState(() {
      _listFuture = _fetchList();
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
    final tabIndex = _tabController.index;
    final filtered = items.where((item) {
      final status = item['status'] ?? 'on_sale';
      if (tabIndex == 1 && status != 'on_sale') return false;
      if (tabIndex == 2 && status != 'offline') return false;
      if (_keyword.isNotEmpty) {
        final community = (item['community'] ?? '').toString();
        if (!community.contains(_keyword)) return false;
      }
      // V8.7 坑 49: filters 空时不调 matches(area_sqm 等段 7.2 后为 null → 默认值 0 < minArea 30)
      if (_filters.isActive && !_filters.matches(item)) return false;
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
            : const Text('我的房源'),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.close : Icons.search),
            tooltip: _searchMode ? '关闭搜索' : '搜索',
            onPressed: _toggleSearch,
          ),
          // 筛选按钮(带激活徽标)
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
              _sortMenuItem('newest', '最新录入', Icons.schedule),
              _sortMenuItem('price_desc', '价格高→低', Icons.arrow_downward),
              _sortMenuItem('price_asc', '价格低→高', Icons.arrow_upward),
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
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '在售'),
            Tab(text: '已下架'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _listFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final data = snapshot.data!;
          final allItems =
              (data['items'] as List).cast<Map<String, dynamic>>();
          final processed = _processItems(allItems);

          if (processed.isEmpty) {
            return _buildEmpty(allItems.isEmpty);
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: processed.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          _headerText(processed.length, allItems.length),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                        if (_filters.isActive) ...[
                          const SizedBox(width: 8),
                          _filterBadge(),
                        ],
                      ],
                    ),
                  );
                }
                final item = processed[index - 1];
                return _ListingCard(
                  item: item,
                  onTap: () async {
                    final changed = await context
                        .push<bool>('/listing/${item['listing_id']}');
                    if (changed == true) _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/listing/new');
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('录入房源'),
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

  String _headerText(int shown, int total) {
    if (_keyword.isNotEmpty || _filters.isActive) {
      return '找到 $shown 套(共 $total 套)';
    }
    return '共 $shown 套房源';
  }

  Widget _buildEmpty(bool totallyEmpty) {
    String title;
    String? subtitle;
    if (totallyEmpty) {
      title = '还没有录入房源';
      subtitle = '点击右下角按钮开始录入';
    } else if (_filters.isActive || _keyword.isNotEmpty) {
      title = '没有符合条件的房源';
      subtitle = '试试调整筛选条件或搜索关键字';
    } else {
      final tabIndex = _tabController.index;
      if (tabIndex == 1) {
        title = '暂无在售房源';
      } else if (tabIndex == 2) {
        title = '暂无已下架房源';
      } else {
        title = '没有房源';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_outlined, size: 80, color: Colors.grey),
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

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  const _ListingCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final addr =
        '${item['community']} ${item['building']}号楼${item['unit']}单元${item['room_no']}';
    final price = item['price_wan'];
    final status = item['status'] ?? 'on_sale';
    final cover = item['cover_thumbnail'] as String?;
    final photoCount = (item['photo_count'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧封面(固定 100x100)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Base64Image(
                        dataUrl: cover,
                        width: 100,
                        height: 100,
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
                  ],
                ),
                const SizedBox(width: 12),
                // 右侧文本(不用 Spacer,靠 mainAxisAlignment 分布)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  addr,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _StatusBadge(status: status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item['layout']} · ${item['area_sqm']}㎡ · ${item['floor']}/${item['total_floor']}层',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '朝向:${item['orientation']}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '¥$price',
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
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 18),
                        ],
                      ),
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
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    switch (status) {
      case 'on_sale':
        label = '在售';
        color = Colors.green;
        break;
      case 'deposit_paid':
        label = '定金已付';
        color = Colors.blue;
        break;
      case 'transaction_ongoing':
        label = '成交进行中';
        color = Colors.orange;
        break;
      case 'paused':
        label = '暂停';
        color = Colors.orange;
        break;
      case 'sold':
        label = '已成交';
        color = Colors.grey;
        break;
      case 'offline':
        label = '已下架';
        color = Colors.grey;
        break;
      default:
        label = status;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}