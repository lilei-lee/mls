import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// 共享房源库(带搜索 + 排序,匿名浏览)
class ListingSharedScreen extends StatefulWidget {
  const ListingSharedScreen({super.key});

  @override
  State<ListingSharedScreen> createState() => _ListingSharedScreenState();
}

class _ListingSharedScreenState extends State<ListingSharedScreen> {
  late Future<Map<String, dynamic>> _listFuture;

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  String _sortKey = 'newest';

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchList() async {
    final response = await ApiClient.instance.dio.get('/listings/shared');
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

  List<Map<String, dynamic>> _processItems(List<Map<String, dynamic>> items) {
    final filtered = items.where((item) {
      if (_keyword.isNotEmpty) {
        final community = (item['community'] ?? '').toString();
        if (!community.contains(_keyword)) return false;
      }
      return true;
    }).toList();

    switch (_sortKey) {
      case 'price_desc':
        filtered.sort((a, b) => (b['price_wan'] as num).compareTo(a['price_wan'] as num));
        break;
      case 'price_asc':
        filtered.sort((a, b) => (a['price_wan'] as num).compareTo(b['price_wan'] as num));
        break;
      case 'area_desc':
        filtered.sort((a, b) => (b['area_sqm'] as num).compareTo(a['area_sqm'] as num));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTextColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

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
                  hintStyle: TextStyle(color: appBarTextColor.withValues(alpha: 0.5)),
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
          final allItems = (data['items'] as List).cast<Map<String, dynamic>>();
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          _headerText(processed.length, allItems.length),
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '匿名浏览',
                            style: TextStyle(color: Colors.blue, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _SharedListingCard(item: processed[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
  PopupMenuItem<String> _sortMenuItem(String value, String label, IconData icon) {
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
    if (_keyword.isNotEmpty) return '找到 $shown 套(共 $total 套)';
    return '共 $shown 套在售房源';
  }

  Widget _buildEmpty(bool totallyEmpty) {
    String title;
    String? subtitle;
    if (totallyEmpty) {
      title = '暂无其他经纪人的共享房源';
      subtitle = '当其他经纪人录入房源后,这里会展示';
    } else if (_keyword.isNotEmpty) {
      title = '没有匹配「$_keyword」的房源';
      subtitle = '试试换个关键字';
    } else {
      title = '没有房源';
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
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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

/// 共享库房源卡片(匿名)
class _SharedListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _SharedListingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final addr = '${item['community']} ${item['building']}号楼${item['unit']}单元${item['room_no']}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              addr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${item['layout']} · ${item['area_sqm']}㎡ · ${item['floor']}/${item['total_floor']}层 · ${item['orientation']}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if ((item['remarks'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text(
                item['remarks'],
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '¥${item['price_wan']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('万', style: TextStyle(color: Colors.red, fontSize: 12)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('申请带客功能将在模块四上线'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('申请带客'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}