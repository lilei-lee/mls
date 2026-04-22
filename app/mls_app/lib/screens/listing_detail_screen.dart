import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../services/transaction_service.dart';
import '../widgets/base64_image.dart';
import '../widgets/info_card.dart';

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

  // ===== V5 交易状态切换 =====

  Future<void> _openStatusBottomSheet(Map<String, dynamic> item) async {
    final status = item['status'] as String;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _StatusChangeSheet(
        currentStatus: status,
        onAction: (action) async {
          Navigator.of(ctx).pop();
          await _handleStatusAction(action);
        },
      ),
    );
  }

  Future<void> _handleStatusAction(String action) async {
    try {
      switch (action) {
        case 'mark_deposit_paid':
          await _confirmAndRun(
            title: '标记定金已付',
            content: '确认买家已付定金?MVP 阶段暂不强制凭证,但请务必真实标记。虚假标记将按违规处理。',
            okText: '确认标记',
            action: () async {
              await ListingStatusService.instance
                  .markDepositPaid(widget.listingId);
            },
            successMsg: '已标记为「定金已付」',
          );
          break;
        case 'mark_transaction_ongoing':
          await _confirmAndRun(
            title: '标记成交进行中',
            content: '确认交易已进入过户流程?此状态下不再接受新的带客申请。',
            okText: '确认标记',
            action: () async {
              await ListingStatusService.instance
                  .markTransactionOngoing(widget.listingId);
            },
            successMsg: '已标记为「成交进行中」',
          );
          break;
        case 'rollback':
          final reason = await showDialog<String>(
            context: context,
            builder: (ctx) => const _RollbackReasonDialog(),
          );
          if (reason == null) return;
          await ListingStatusService.instance
              .rollbackToOnSale(widget.listingId, reason);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已回退到「在售」')),
          );
          _reload();
          break;
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String content,
    required String okText,
    required Future<void> Function() action,
    required String successMsg,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okText, style: const TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(successMsg)));
    _reload();
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
            final status = item['status'] as String;
            final isOffline = status == 'offline';
            final isSold = status == 'sold';
            final isOnSale = status == 'on_sale';
            final isInTransaction =
                status == 'deposit_paid' || status == 'transaction_ongoing';

            final photos =
                ((item['photos'] as List?) ?? []).cast<Map<String, dynamic>>();

            return ListView(
              padding: EdgeInsets.zero,
              children: [
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
                          _StatusBadge(status: status),
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

                      if (isSold) _soldPriceCard(item) else _askingPriceCard(item),

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

                      if (isSold)
                        _soldActionsSection()
                      else if (isOffline)
                        _offlineActionsSection()
                      else ...[
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
                          child: ElevatedButton.icon(
                            onPressed: () => _openStatusBottomSheet(item),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('变更交易状态'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isOnSale)
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
                        if (isInTransaction)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.grey, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '交易状态下不能直接下架,请先回退到「在售」',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ),
                              ],
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

  Widget _askingPriceCard(Map<String, dynamic> item) {
    return Card(
      color: Colors.red.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('挂牌价',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _soldPriceCard(Map<String, dynamic> item) {
    final soldPriceYuan = item['sold_price_yuan'];
    final soldDate = item['sold_date'] as String?;
    final wan = soldPriceYuan != null
        ? ((soldPriceYuan as num) / 10000).toStringAsFixed(1)
        : '-';
    return Card(
      color: Colors.green.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('成交价',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                Text(
                  '¥$wan',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('万',
                    style: TextStyle(color: Colors.green, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text('成交日期:${soldDate ?? '-'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 12),
                const Text('·',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 12),
                Text('原挂牌:¥${item['price_wan']}万',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _soldActionsSection() {
    return Card(
      color: Colors.green.withValues(alpha: 0.05),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '该房源已通过成交确认流程生效,不可再编辑。成交价和成交日期已在共享库公开展示。',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offlineActionsSection() {
    return Column(
      children: [
        Card(
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 20),
                SizedBox(width: 10),
                Expanded(
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
    );
  }
}

// ========== 交易状态切换 BottomSheet ==========
class _StatusChangeSheet extends StatelessWidget {
  final String currentStatus;
  final void Function(String action) onAction;
  const _StatusChangeSheet({
    required this.currentStatus,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('变更交易状态',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('当前:${_label(currentStatus)}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (currentStatus == 'on_sale') ...[
              _tile(
                icon: Icons.payment,
                color: Colors.orange,
                title: '标记「定金已付」',
                subtitle: '买家已付定金(种子期暂不强制上传凭证)',
                onTap: () => onAction('mark_deposit_paid'),
              ),
              _tile(
                icon: Icons.fact_check,
                color: Colors.blue,
                title: '直接标记「成交进行中」',
                subtitle: '无定金交易直接签约(需合同凭证,MVP 暂不强制)',
                onTap: () => onAction('mark_transaction_ongoing'),
              ),
            ] else if (currentStatus == 'deposit_paid') ...[
              _tile(
                icon: Icons.fact_check,
                color: Colors.blue,
                title: '标记「成交进行中」',
                subtitle: '过户流程启动,不再接受带客申请',
                onTap: () => onAction('mark_transaction_ongoing'),
              ),
              _tile(
                icon: Icons.undo,
                color: Colors.red,
                title: '回退到「在售」',
                subtitle: '买方反悔或交易取消',
                onTap: () => onAction('rollback'),
              ),
            ] else if (currentStatus == 'transaction_ongoing') ...[
              _tile(
                icon: Icons.undo,
                color: Colors.red,
                title: '回退到「在售」',
                subtitle: '交易取消,需要选原因',
                onTap: () => onAction('rollback'),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '进入已售:只能通过 BA 发起的成交确认流程自动触发,不能手动操作。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '当前状态不支持手动切换',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  String _label(String s) {
    switch (s) {
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
    }
    return s;
  }
}

class _RollbackReasonDialog extends StatefulWidget {
  const _RollbackReasonDialog();

  @override
  State<_RollbackReasonDialog> createState() => _RollbackReasonDialogState();
}

class _RollbackReasonDialogState extends State<_RollbackReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('回退到「在售」'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请填写回退原因(如买方反悔、交易取消等):',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            maxLines: 2,
            maxLength: 100,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '如:买方反悔',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '⚠️ 若该房源有正在进行的成交确认,请先由 BA 撤回后再回退',
            style: TextStyle(color: Colors.orange, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final t = _controller.text.trim();
            if (t.isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请填写原因')));
              return;
            }
            Navigator.of(context).pop(t);
          },
          child: const Text('确认回退', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

// ========== 照片轮播 ==========
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
      case 'deposit_paid':
        label = '定金已付';
        color = Colors.orange;
        break;
      case 'transaction_ongoing':
        label = '成交进行中';
        color = Colors.blue;
        break;
      case 'sold':
        label = '已成交';
        color = Colors.grey;
        break;
      case 'paused':
        label = '暂停';
        color = Colors.orange;
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