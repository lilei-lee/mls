import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../widgets/base64_image.dart';
import '../widgets/info_card.dart';

/// 房源详情页
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _listChanged = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final response =
        await ApiClient.instance.dio.get('/listings/${widget.listingId}');
    return response.data['data'] as Map<String, dynamic>;
  }

  void _reload() {
    setState(() {
      _future = _fetch();
    });
    _listChanged = true;
  }

  Future<void> _offline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下架房源'),
        content: const Text('下架后房源在共享库不再展示,但数据会保留。以后可以重新上架。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定下架', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient.instance.dio.delete('/listings/${widget.listingId}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('房源已下架')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('下架失败:$msg')));
    }
  }

  Future<void> _reactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新上架'),
        content: const Text('确定把这条房源重新上架到共享库吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重新上架', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient.instance.dio.post(
        '/listings/${widget.listingId}/reactivate',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('房源已重新上架')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('上架失败:$msg')));
    }
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
        appBar: AppBar(
          title: const Text('房源详情'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_listChanged),
          ),
        ),
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
            final isOffline = item['status'] == 'offline';

            // 照片数组
            final photos =
                ((item['photos'] as List?) ?? []).cast<Map<String, dynamic>>();

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // 段 8:顶部照片轮播(占满宽度)
                _PhotoCarousel(photos: photos),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['community']} ${item['building']}号楼${item['unit']}单元${item['room_no']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _StatusBadge(status: item['status']),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '一户一码:${item['house_code']}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.red.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text('报价',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                              const SizedBox(width: 12),
                              Text(
                                '¥${item['price_wan']}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('万',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if ((item['district'] ?? '').toString().isNotEmpty)
                        InfoCard(label: '行政区', value: item['district']),
                      InfoCard(label: '户型', value: item['layout'] ?? '-'),
                      InfoCard(label: '建筑面积', value: '${item['area_sqm']}㎡'),
                      InfoCard(
                          label: '楼层',
                          value: '${item['floor']}/${item['total_floor']}层'),
                      InfoCard(label: '朝向', value: item['orientation'] ?? '-'),
                      if ((item['remarks'] as String?)?.isNotEmpty ?? false)
                        InfoCard(label: '备注', value: item['remarks']),
                      const SizedBox(height: 24),
                      if (!isOffline) ...[
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final changed = await context.push<bool>(
                                '/listing/${widget.listingId}/edit',
                                extra: item,
                              );
                              if (changed == true) _reload();
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('编辑房源'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _offline,
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('下架'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ] else ...[
                        Card(
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.grey, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    '该房源已下架,在共享库不再展示',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _reactivate,
                            icon: const Icon(Icons.unarchive),
                            label: const Text('重新上架'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 照片轮播组件(详情页顶部)
class _PhotoCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 没有照片时:占位符
    if (widget.photos.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 8),
            Text('暂无照片',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) {
              final p = widget.photos[i];
              return GestureDetector(
                onTap: () => _openFullscreen(i),
                child: Container(
                  color: Colors.black,
                  child: Base64Image(
                    dataUrl: p['data'] as String?,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          // 右下角页码
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.photos.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenViewer(
          photos: widget.photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 全屏看图(黑底 + 可滑动)
class _FullscreenViewer extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  const _FullscreenViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.photos.length}'),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (ctx, i) {
          final p = widget.photos[i];
          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Base64Image(
                dataUrl: p['data'] as String?,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}