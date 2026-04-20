import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/showing_request.dart';
import '../services/showing_request_service.dart';

/// 带客申请详情页
/// - LA 和 BA 都能进,按 viewer_role 决定 UI
class ShowingRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const ShowingRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ShowingRequestDetailScreen> createState() =>
      _ShowingRequestDetailScreenState();
}

class _ShowingRequestDetailScreenState
    extends State<ShowingRequestDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = ShowingRequestService.instance.detail(widget.requestId);
  }

  void _reload() {
    setState(() {
      _future = ShowingRequestService.instance.detail(widget.requestId);
    });
  }

  // ----- LA 审批通过 -----
  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('同意带客申请'),
        content: const Text('通过后双方身份互通,对方可联系您。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('同意', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await ShowingRequestService.instance.approve(widget.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已同意,双方身份已公开')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ----- LA 审批拒绝 -----
  Future<void> _reject() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => const _RejectDialog(),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      await ShowingRequestService.instance.reject(
        widget.requestId,
        reason: result['reason']!,
        extra: result['extra'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已拒绝')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ----- 一键拨号 -----
  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // fallback:复制到剪贴板
        await Clipboard.setData(ClipboardData(text: phone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已复制号码到剪贴板:$phone')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制号码到剪贴板:$phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('带客申请详情')),
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
                  const Icon(Icons.error_outline,
                      size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败:${snap.error}',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _reload, child: const Text('重试')),
                ],
              ),
            );
          }

          final data = snap.data!;
          final status = ShowingRequestStatus.fromString(data['status']);
          final viewerRole = data['viewer_role'] as String;
          final isLA = viewerRole == 'listing_agent';
          final snapshot = data['listing_snapshot'] as Map<String, dynamic>;
          final counter = data['counterparty'] as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 状态横幅
              _statusBanner(status),
              const SizedBox(height: 16),

              // 房源信息卡片
              _sectionTitle('目标房源'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${snapshot['community']} ${snapshot['building']}号楼${snapshot['unit']}单元${snapshot['room_no']}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${snapshot['layout'] ?? ''} · ${snapshot['area_sqm']}㎡ · ¥${snapshot['price_wan']}万',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 客户信息卡片
              _sectionTitle('客户信息'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${data['customer_surname']}${data['customer_gender'] == 'male' ? '先生' : '女士'}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('需求',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        data['requirements'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 对方身份(根据状态显示)
              _counterpartySection(counter, status, isLA),
              const SizedBox(height: 16),

              // 拒绝理由
              if (status == ShowingRequestStatus.rejected) ...[
                _sectionTitle('拒绝理由'),
                Card(
                  color: Colors.grey.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['reject_reason_text'] ?? '-',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (data['reject_extra'] != null &&
                            data['reject_extra'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '补充说明:${data['reject_extra']}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // LA 的审批按钮(只有 pending 且 LA 视角时显示)
              if (isLA && status == ShowingRequestStatus.pending) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _reject,
                          icon: const Icon(Icons.close),
                          label: const Text('拒绝'),
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
                          onPressed: _submitting ? null : _approve,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('同意'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // 已通过 → 显示拨号按钮
              if (status == ShowingRequestStatus.approved &&
                  counter['phone'] != null &&
                  counter['phone'].toString().isNotEmpty) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(counter['phone']),
                    icon: const Icon(Icons.phone),
                    label: Text(
                      '拨打 ${counter['name']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '点击拨号将调用系统拨号盘,平台会记录该拨号动作',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ----- 子组件 -----

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusBanner(ShowingRequestStatus status) {
    late Color color;
    late IconData icon;
    late String text;
    switch (status) {
      case ShowingRequestStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = '待审批';
        break;
      case ShowingRequestStatus.approved:
        color = Colors.green;
        icon = Icons.check_circle;
        text = '已通过,双方身份已公开';
        break;
      case ShowingRequestStatus.rejected:
        color = Colors.grey;
        icon = Icons.block;
        text = '已拒绝';
        break;
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
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _counterpartySection(
    Map<String, dynamic> counter,
    ShowingRequestStatus status,
    bool isLA,
  ) {
    final label = isLA ? '带客经纪人' : '房源归属人';
    final anonymous = counter['anonymous'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: anonymous
                ? Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.visibility_off,
                            color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '审批通过后可见',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            counter['name'] ?? '-',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (counter['store'] != null &&
                          counter['store'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '门店:${counter['store']}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// 拒绝理由对话框
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  String? _selectedReason;
  final _extraController = TextEditingController();

  @override
  void dispose() {
    _extraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('拒绝带客申请'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请选择拒绝理由:',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          ...RejectReasons.all.entries.map((e) {
            return RadioListTile<String>(
              value: e.key,
              groupValue: _selectedReason,
              title: Text(e.value, style: const TextStyle(fontSize: 14)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _selectedReason = v),
            );
          }),
          if (_selectedReason == 'other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _extraController,
              maxLines: 2,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: '请说明原因',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  if (_selectedReason == 'other' &&
                      _extraController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请填写补充说明')),
                    );
                    return;
                  }
                  Navigator.of(context).pop({
                    'reason': _selectedReason!,
                    'extra': _extraController.text.trim(),
                  });
                },
          child: const Text('确定拒绝',
              style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}