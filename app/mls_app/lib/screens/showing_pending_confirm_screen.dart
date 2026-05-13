import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/showing_service.dart';
import '../widgets/mls/mls_card.dart';

/// LA 视角:待我确认的带看列表
class ShowingPendingConfirmScreen extends StatefulWidget {
  const ShowingPendingConfirmScreen({super.key});

  @override
  State<ShowingPendingConfirmScreen> createState() =>
      _ShowingPendingConfirmScreenState();
}

class _ShowingPendingConfirmScreenState
    extends State<ShowingPendingConfirmScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShowingService.instance.listPendingConfirm();
  }

  void _reload() {
    setState(() {
      _future = ShowingService.instance.listPendingConfirm();
    });
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待我确认的带看'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<Map<String, dynamic>>(
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
            final items =
                (snap.data!['items'] as List).cast<Map<String, dynamic>>();
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text('暂无待确认的带看记录',
                        style: TextStyle(color: Colors.grey, fontSize: 12.0)),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final it = items[i];
                final sp = Map<String, dynamic>.from(it['listing_snapshot']);
                return MlsCard(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () async {
                      final result = await context
                          .push<bool>('/showing/${it['showing_id']}/confirm');
                      if (result == true) _reload();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Text('待确认',
                                    style: TextStyle(
                                        color: MlsColors.warning,
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              Icon(Icons.camera_alt_outlined,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text('${it['photo_count']}张',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11.0)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${sp['community']} ${sp['building']}-${sp['unit']}-${sp['room_no']}',
                            style: const TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · ¥${sp['price_wan']}万',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11.0),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('BA:${it['ba_agent_name']}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11.0)),
                              const SizedBox(width: 12),
                              const Icon(Icons.access_time,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(_formatTime(it['showing_time']),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11.0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}