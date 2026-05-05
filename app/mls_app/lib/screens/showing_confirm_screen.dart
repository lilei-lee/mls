import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/showing_service.dart';

/// LA 查看并确认带看记录
class ShowingConfirmScreen extends StatefulWidget {
  final String showingId;
  const ShowingConfirmScreen({super.key, required this.showingId});

  @override
  State<ShowingConfirmScreen> createState() => _ShowingConfirmScreenState();
}

class _ShowingConfirmScreenState extends State<ShowingConfirmScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = ShowingService.instance.detail(widget.showingId);
  }

  void _reload() {
    setState(() {
      _future = ShowingService.instance.detail(widget.showingId);
    });
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认带看'),
        content: const Text('确认后本次带看记录正式生效,写入交易留痕链。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      await ShowingService.instance.confirm(widget.showingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('带看已确认')));
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RejectDialog(),
    );
    if (reason == null) return;

    setState(() => _submitting = true);
    try {
      await ShowingService.instance.reject(widget.showingId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已驳回')));
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _viewPhoto(String b64, int index, int total) {
    final commaIdx = b64.indexOf(',');
    final raw = commaIdx > 0 ? b64.substring(commaIdx + 1) : b64;
    final bytes = base64Decode(raw);

    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('照片 ${index + 1}/$total'),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(bytes),
          ),
        ),
      ),
    ));
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认带看记录')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败:${snap.error}',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _reload, child: const Text('重试')),
                ],
              ),
            );
          }

          final d = snap.data!;
          final status = d['status'] as String;
          final photos = (d['photos'] as List?)?.cast<String>() ?? [];
          final sp = Map<String, dynamic>.from(d['listing_snapshot']);
          final notes = (d['notes'] as String?) ?? '';
          final isPending = status == 'pending_confirm';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusBanner(status, d['reject_reason'] as String?),
              const SizedBox(height: 16),

              _sectionTitle('目标房源'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sp['community']} ${sp['building']}号楼${sp['unit']}单元${sp['room_no']}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · ¥${sp['price_wan']}万',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('带看时间'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_formatTime(d['showing_time']),
                          style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('现场照片(${photos.length} 张,点击放大)'),
              _buildPhotoGrid(photos),
              const SizedBox(height: 16),

              if (notes.isNotEmpty) ...[
                _sectionTitle('带看备注'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(notes, style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _sectionTitle('带客经纪人'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        d['ba_agent_name'] ?? '-',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _reject,
                          icon: const Icon(Icons.close),
                          label: const Text('驳回'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _confirm,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check),
                          label: const Text('确认带看'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: const TextStyle(
              color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBanner(String status, String? rejectReason) {
    late Color color;
    late IconData icon;
    late String text;
    switch (status) {
      case 'pending_confirm':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = '待您确认';
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        text = '带看已确认,已进入交易留痕链';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.block;
        text = '已驳回${rejectReason != null ? ":$rejectReason" : ""}';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
        text = status;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photos) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing, runSpacing: spacing,
          children: List.generate(photos.length, (i) {
            final b64 = photos[i];
            final commaIdx = b64.indexOf(',');
            final raw = commaIdx > 0 ? b64.substring(commaIdx + 1) : b64;
            final bytes = base64Decode(raw);
            return GestureDetector(
              onTap: () => _viewPhoto(b64, i, photos.length),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(bytes,
                    width: w, height: w, fit: BoxFit.cover),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('驳回带看记录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请简要说明驳回原因,BA 可根据此反馈重新提交:',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 100,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '如:照片非现场,或时间与我记录不符',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final t = _controller.text.trim();
            if (t.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请填写驳回理由')),
              );
              return;
            }
            Navigator.of(context).pop(t);
          },
          child: const Text('确定驳回', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}