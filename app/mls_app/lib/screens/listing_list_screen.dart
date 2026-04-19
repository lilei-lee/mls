import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

/// 我的房源列表页(分类 Tab + 搜索 + 排序)
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

  List<Map<String, dynamic>> _processItems(
    List<Map<String, dynamic>> items,
  ) {
    final tabIndex = _tabController.index;
    final filtered = items.where((item) {
      final status = item['status'] ?? 'on_sale';
      if (tabIndex == 1 && status != 'on_sale') return false;
      if (tabIndex == 2 && status != 'offline') return false;
      if (_keyword.isNotEmpty) {
        final community = (item['community'] ?? '').toString();
        if (!community.contains(_keyword)) return false;
      }
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
    // 拿主题里 AppBar 文字的颜色,搜索框字色跟它一致,保证可见
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
                    child: Text(
                      _headerText(processed.length, allItems.length),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final item = processed[index - 1];
                return _ListingCard(
                  item: item,
                  onTap: () async {
                    final changed = await context.push<bool>(
                      '/listing/${item['listing_id']}',
                    );
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
    if (_keyword.isNotEmpty) {
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
    } else if (_keyword.isNotEmpty) {
      title = '没有匹配「$_keyword」的房源';
      subtitle = '试试换个关键字';
    } else {
      final tabIndex = _tabController.index;
      if (tabIndex == 1) {
        title = '暂无在售房源';
        subtitle = null;
      } else if (tabIndex == 2) {
        title = '暂无已下架房源';
        subtitle = null;
      } else {
        title = '没有房源';
        subtitle = null;
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      addr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${item['layout']} · ${item['area_sqm']}㎡ · ${item['floor']}/${item['total_floor']}层 · ${item['orientation']}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '¥$price',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '万',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                ],
              ),
            ],
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
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}