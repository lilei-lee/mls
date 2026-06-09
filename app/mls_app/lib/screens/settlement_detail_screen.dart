import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/settlement_service.dart';
import '../widgets/mls/mls_card.dart';

/// 奖金结算单详情
///
/// 状态路径:pending_payment → pending_receipt → settled
///
/// 本 MVP 只做 LA 的"我已付款"动作(pending_payment → pending_receipt)。
/// BA 确认收款带证据上传,等 B 对象存储迁完后补。
class SettlementDetailScreen extends StatefulWidget {
  final String settlementId;
  const SettlementDetailScreen({super.key, required this.settlementId});

  @override
  State<SettlementDetailScreen> createState() =>
      _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends State<SettlementDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _submitting = false;
  bool _dirty = false; // 本次是否改动过,用于 pop 返回给列表页

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = SettlementService.instance.detail(widget.settlementId);
    });
  }

  /// LA 标记已付款
  Future<void> _openLaMarkPaidDialog() async {
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _LaMarkPaidDialog(),
    );
    if (note == null) return; // 取消

    setState(() => _submitting = true);
    try {
      await SettlementService.instance.laMarkPaid(
        widget.settlementId,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      _dirty = true;
      _snack('✓ 已标记已付款,等待对方确认收款');
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('操作失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // 返回时把 dirty 带回列表页触发刷新
        // (PopScope 无法改已 pop 的结果,这里留给 pop 前手动 pop(dirty))
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('奖金结算详情'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_dirty),
          ),
        ),
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
                        size: 60, color: MlsColors.danger),
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

            final doc = snap.data!;
            final sp = Map<String, dynamic>.from(doc['listing_snapshot'] ?? {});
            final status = doc['status'] as String;
            final role = doc['viewer_role'] as String?;
            final isLA = role == 'la';
            final isBA = role == 'ba';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusBanner(status),
                const SizedBox(height: 16),

                _sectionTitle('房源'),
                MlsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sp['community'] ?? '-'} ${sp['building'] ?? ''}号楼'
                          '${sp['unit'] ?? ''}单元${sp['room_no'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sp['layout'] ?? ''} · ${sp['area_sqm'] ?? '-'}㎡',
                          style: const TextStyle(
                              fontSize: 11.0, color: MlsColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _sectionTitle('结算信息'),
                MlsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kvRow('买方经纪人', doc['ba_agent_name'] ?? '-'),
                        const SizedBox(height: 6),
                        _kvRow('卖方经纪人', doc['la_agent_name'] ?? '-'),
                        const Divider(height: 20),
                        _kvRow('成交价',
                            '¥${((doc['deal_price_yuan'] as num?)?.toInt() ?? 0)} 元'
                            '(约 ${(((doc['deal_price_yuan'] as num?)?.toInt() ?? 0) / 10000).toStringAsFixed(1)} 万)'),
                        const SizedBox(height: 6),
                        _kvRow('成交日期', doc['deal_date'] ?? '-'),
                        const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text('合作奖金',
                                style: TextStyle(
                                    fontSize: 12.0, color: MlsColors.textTertiary)),
                            const SizedBox(width: 12),
                            Text(
                              '¥${(doc['bonus_yuan'] as num?)?.toInt() ?? 0}',
                              style: const TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                                color: MlsColors.warning,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('元',
                                style: TextStyle(
                                    fontSize: 11.0, color: MlsColors.textTertiary)),
                            const SizedBox(width: 10),
                            Text(
                              '≈ ${(((doc['bonus_yuan'] as num?)?.toInt() ?? 0) / 10000).toStringAsFixed(2)} 万',
                              style: const TextStyle(
                                  fontSize: 11.0, color: MlsColors.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '金额锁定 = BA 提交成交确认时 LA 设定的奖金值',
                          style: TextStyle(fontSize: 11.0, color: MlsColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _sectionTitle('进度'),
                _buildTimeline(doc),
                const SizedBox(height: 20),

                _buildActionButtons(status, isLA, isBA, doc),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: const TextStyle(
              color: MlsColors.textTertiary,
              fontSize: 12.0,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _kvRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(k,
              style: const TextStyle(fontSize: 12.0, color: MlsColors.textTertiary)),
        ),
        Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 12.0, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _statusBanner(String status) {
    late Color color;
    late IconData icon;
    late String text;
    switch (status) {
      case 'pending_payment':
        color = MlsColors.warning;
        icon = Icons.hourglass_empty;
        text = '待 LA 付款';
        break;
      case 'pending_receipt':
        color = MlsColors.primary;
        icon = Icons.access_time;
        text = 'LA 已付款,等待 BA 确认收款';
        break;
      case 'settled':
        color = MlsColors.success;
        icon = Icons.verified;
        text = '已结清';
        break;
      case 'disputed':
        color = MlsColors.danger;
        icon = Icons.error_outline;
        text = '有异议,待人工处理';
        break;
      default:
        color = MlsColors.textTertiary;
        icon = Icons.info_outline;
        text = status;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> doc) {
    final createdAt = doc['created_at'] as String?;
    final laPaidAt = doc['la_paid_at'] as String?;
    final laNote = doc['la_payment_note'] as String?;
    final baReceivedAt = doc['ba_received_at'] as String?;
    final settledAt = doc['settled_at'] as String?;

    return MlsCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _timelineTile(
              done: createdAt != null,
              title: '结算单生成',
              subtitle: _fmtTime(createdAt),
            ),
            _timelineTile(
              done: laPaidAt != null,
              title: 'LA 标记已付款',
              subtitle: laPaidAt != null
                  ? '${_fmtTime(laPaidAt)}${laNote != null ? '\n备注:$laNote' : ''}'
                  : '待 LA 操作',
            ),
            _timelineTile(
              done: baReceivedAt != null,
              title: 'BA 确认已收款',
              subtitle: baReceivedAt != null
                  ? _fmtTime(baReceivedAt)
                  : '待 BA 操作(功能即将开放)',
              isLast: settledAt == null,
            ),
            if (settledAt != null)
              _timelineTile(
                done: true,
                title: '已结清',
                subtitle: _fmtTime(settledAt),
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineTile({
    required bool done,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    final dotColor = done ? Colors.green : MlsColors.textTertiary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done
                        ? MlsColors.success.withValues(alpha: 0.3)
                        : MlsColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: isLast ? 0 : 16, top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: done ? MlsColors.textPrimary : MlsColors.textTertiary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.0, color: MlsColors.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '-';
    try {
      final t = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${t.year}-${two(t.month)}-${two(t.day)} '
          '${two(t.hour)}:${two(t.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildActionButtons(
    String status,
    bool isLA,
    bool isBA,
    Map<String, dynamic> doc,
  ) {
    if (_submitting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // LA 视角 + pending_payment:可以标记已付款
    if (isLA && status == 'pending_payment') {
      return SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _openLaMarkPaidDialog,
          icon: const Icon(Icons.payment),
          label: const Text('我已付款'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MlsColors.success,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    // BA 视角 + pending_receipt:等 B 做完后补
    if (isBA && status == 'pending_receipt') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MlsColors.primaryBg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: MlsColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 6),
                Text('收款确认即将开放',
                    style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: MlsColors.primary)),
              ],
            ),
            SizedBox(height: 6),
            Text(
              '收款确认需要上传微信转账 / 银行回单截图作为凭证。'
              '该功能将在下次版本更新中提供。'
              '在此之前,如已收到款,建议与 LA 线下确认。',
              style: TextStyle(fontSize: 11.0, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ==================== 对话框 ====================

class _LaMarkPaidDialog extends StatefulWidget {
  const _LaMarkPaidDialog();

  @override
  State<_LaMarkPaidDialog> createState() => _LaMarkPaidDialogState();
}

class _LaMarkPaidDialogState extends State<_LaMarkPaidDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('标记已付款'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '确认您已通过线下(微信转账/银行转账等)把奖金支付给对方。'
            '此操作会将结算单状态变为"待 BA 确认收款"。',
            style: TextStyle(fontSize: 11.0, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: '备注(选填)',
              hintText: '例如:微信转账,2026-04-23',
              border: OutlineInputBorder(),
            ),
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
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('确认已付款', style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}