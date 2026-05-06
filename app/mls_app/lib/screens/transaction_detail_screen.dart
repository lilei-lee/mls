import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/transaction_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = TransactionService.instance.detail(widget.transactionId);
    });
  }

  // ============ LA 确认(独立填价) ============

  Future<void> _openLaConfirmDialog(Map<String, dynamic> doc) async {
    final result = await showDialog<_LaConfirmResult>(
      context: context,
      builder: (ctx) => _LaConfirmDialog(snapshot: doc['listing_snapshot']),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      final updated = await TransactionService.instance.laConfirm(
        widget.transactionId,
        dealPriceYuan: result.priceYuan,
        dealDate: result.date,
      );
      if (!mounted) return;
      if (updated['status'] == 'confirmed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ 价格一致,成交已生效!房源自动转为已成交。'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('价格或日期不一致,系统已自动驳回'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('操作失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ============ LA 手动驳回 ============

  Future<void> _openLaRejectDialog() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _LaRejectDialog(),
    );
    if (reason == null) return;

    setState(() => _submitting = true);
    try {
      await TransactionService.instance
          .laReject(widget.transactionId, reason);
      if (!mounted) return;
      _snack('已驳回');
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('操作失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ============ BA 修改自己填报 ============

  Future<void> _openBaUpdateDialog(Map<String, dynamic> doc) async {
    final result = await showDialog<_BaUpdateResult>(
      context: context,
      builder: (ctx) => _BaUpdateDialog(
        currentPrice: doc['ba_deal_price_yuan'] as int?,
        currentDate: doc['ba_deal_date'] as String?,
        currentNotes: doc['ba_notes'] as String?,
      ),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      await TransactionService.instance.updateMySubmission(
        widget.transactionId,
        dealPriceYuan: result.priceYuan,
        dealDate: result.date,
        notes: result.notes,
      );
      if (!mounted) return;
      _snack('已重新提交,等待 LA 再次确认');
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('修改失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ============ LA 修改自己填报 ============

  Future<void> _openLaUpdateDialog(Map<String, dynamic> doc) async {
    final result = await showDialog<_LaUpdateResult>(
      context: context,
      builder: (ctx) => _LaUpdateDialog(
        currentPrice: doc['la_deal_price_yuan'] as int?,
        currentDate: doc['la_deal_date'] as String?,
      ),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      await TransactionService.instance.laUpdateMySubmission(
        widget.transactionId,
        dealPriceYuan: result.priceYuan,
        dealDate: result.date,
      );
      if (!mounted) return;
      _snack('已重新提交,等待系统比对');
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('修改失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ============ BA 撤回 ============

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回成交确认'),
        content: const Text('撤回后此记录作废,您可以重新发起。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('不撤回'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认撤回', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      await TransactionService.instance.cancel(widget.transactionId);
      if (!mounted) return;
      _snack('已撤回');
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('撤回失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('成交确认详情')),
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

          final doc = snap.data!;
          final sp = Map<String, dynamic>.from(doc['listing_snapshot']);
          final status = doc['status'] as String;

          // V7.1 新:用后端返的 viewer_role 判身份,不再靠姓名兜底
          final role = doc['viewer_role'] as String?;
          final isBA = role == 'ba';
          final isLA = role == 'la';
          // 视角隔离铁律:与后端 _format 的 not_confirmed 判断对称(transactions.py:586)
          // 任何修改必须前后端同步,否则一边裸奔
          final maskBa = isLA && status != 'confirmed';
          final maskLa = isBA && status != 'confirmed';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusBanner(status, doc),
              const SizedBox(height: 16),

              _sectionTitle('成交房源'),
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
                        '${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · 挂牌 ¥${sp['price_wan']}万',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('双方填报'),
              _buildSubmissionCards(doc, maskBa: maskBa, maskLa: maskLa),
              const SizedBox(height: 16),

              // BA 备注:LA 视角在 pending_la_confirm 下也要脱敏
              if (!maskBa &&
                  ((doc['ba_notes'] as String?)?.isNotEmpty ?? false)) ...[
                _sectionTitle('BA 备注'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(doc['ba_notes'],
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildActionButtons(status, isBA, isLA, doc),
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

  Widget _statusBanner(String status, Map<String, dynamic> doc) {
    late Color color;
    late IconData icon;
    late String text;
    switch (status) {
      case 'pending_la_confirm':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = '等待 LA 独立填价确认';
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        final p = doc['la_deal_price_yuan'] ?? doc['ba_deal_price_yuan'];
        if (p != null) {
          final wan = (p as num).toDouble() / 10000;
          text =
              '成交已生效 · ¥${wan.toStringAsFixed(1)} 万 · ${doc['ba_deal_date'] ?? doc['la_deal_date']}';
        } else {
          text = '成交已生效';
        }
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.block;
        final kind = doc['reject_kind'];
        if (kind == 'price_mismatch') {
          text = '系统自动驳回:${doc['reject_reason'] ?? '双方填报不一致'}';
        } else {
          text = 'LA 驳回:${doc['reject_reason'] ?? '-'}';
        }
        break;
      case 'cancelled':
        color = Colors.grey;
        icon = Icons.cancel_outlined;
        text = '已撤回';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCards(Map<String, dynamic> doc,
      {required bool maskBa, required bool maskLa}) {
    // maskBa=true 时,BA 卡片强制脱敏;ba_has_submitted 用于判"填了还是没填"
    final baHasSubmitted = (doc['ba_has_submitted'] as bool?) ?? false;

    return Column(
      children: [
        _submissionTile(
          roleLabel: 'Buyer\'s Agent',
          agentName: doc['ba_agent_name'] ?? '-',
          priceYuan: maskBa ? null : doc['ba_deal_price_yuan'] as int?,
          dateStr: maskBa ? null : doc['ba_deal_date'] as String?,
          submittedAt: doc['ba_submitted_at'] as String?,
          color: Colors.blue,
          masked: maskBa,
          hasSubmitted: baHasSubmitted,
        ),
        const SizedBox(height: 8),
        _submissionTile(
          roleLabel: 'Listing Agent',
          agentName: doc['la_agent_name'] ?? '-',
          priceYuan: maskLa ? null : doc['la_deal_price_yuan'] as int?,
          dateStr: maskLa ? null : doc['la_deal_date'] as String?,
          submittedAt: maskLa ? null : doc['la_submitted_at'] as String?,
          color: Colors.purple,
          masked: maskLa,
          hasSubmitted: doc['la_submitted_at'] != null,
        ),
      ],
    );
  }

  /// masked=true:防伪脱敏展示"已提交(防伪隐去)"
  /// hasSubmitted=true 且 !masked:展示实际填报
  /// 否则:尚未填报
  Widget _submissionTile({
    required String roleLabel,
    required String agentName,
    required int? priceYuan,
    required String? dateStr,
    required String? submittedAt,
    required Color color,
    required bool masked,
    required bool hasSubmitted,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(roleLabel,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(agentName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),

            if (masked && hasSubmitted) ...[
              // 防伪:LA 视角 + 待确认状态 —— 告诉 LA "对方已提交",但隐去价格
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    '已提交',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '防伪机制:请您独立填写记忆中的成交价,系统将自动比对。',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ] else if (priceYuan != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$priceYuan',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Text('元',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 10),
                  Text('≈ ${(priceYuan / 10000).toStringAsFixed(1)} 万',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text('成交日期:${dateStr ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ] else
              const Text('尚未填报',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    String status,
    bool isBA,
    bool isLA,
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

    // pending_la_confirm:BA 可撤回;LA 可确认/驳回
    if (status == 'pending_la_confirm') {
      if (isBA) {
        return SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _cancel,
            icon: const Icon(Icons.undo),
            label: const Text('撤回成交确认'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        );
      }
      if (isLA) {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openLaRejectDialog,
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
                  onPressed: () => _openLaConfirmDialog(doc),
                  icon: const Icon(Icons.gavel),
                  label: const Text('独立填价'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    // rejected:BA 可修改重提 / LA 可修改自己填报
    if (status == 'rejected') {
      if (isBA) {
        final rejectKind = doc['reject_kind'] as String?;
        if (rejectKind == 'manual') {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LA 手动驳回了此成交确认,请联系 LA 沟通后重新发起',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.undo),
                  label: const Text('撤回成交确认'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请与 LA 核对后修改填报重新提交',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _openBaUpdateDialog(doc),
                icon: const Icon(Icons.edit),
                label: const Text('修改并重新提交'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      }
      if (isLA) {
        final rejectKind = doc['reject_kind'] as String?;
        if (rejectKind == 'manual') {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '价格比对不一致,请核实后修改你的填报重新提交',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _openLaUpdateDialog(doc),
                icon: const Icon(Icons.edit),
                label: const Text('修改我的填报'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      }
    }

    // confirmed / cancelled / 其他:只读展示
    return const SizedBox.shrink();
  }
}

// ==================== 子对话框 ====================

class _LaConfirmResult {
  final int priceYuan;
  final String date;
  _LaConfirmResult(this.priceYuan, this.date);
}

class _LaConfirmDialog extends StatefulWidget {
  final Map<String, dynamic> snapshot;
  const _LaConfirmDialog({required this.snapshot});

  @override
  State<_LaConfirmDialog> createState() => _LaConfirmDialogState();
}

class _LaConfirmDialogState extends State<_LaConfirmDialog> {
  final _priceController = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  int? get _priceYuan =>
      int.tryParse(_priceController.text.trim().isEmpty
          ? '0'
          : _priceController.text.trim());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _dateStr(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _priceYuan;
    final wan =
        (p != null && p > 0) ? (p / 10000).toStringAsFixed(1) : '--';

    return AlertDialog(
      title: const Text('独立填写成交价'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ 您看不到 BA 填的价格,系统会独立比对。请如实填写您记录的成交价,单位:元。',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '成交价',
                hintText: '例如 850000',
                suffixText: '元',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('约 $wan 万元',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _date == null ? '选择成交日期' : _dateStr(_date!),
                      style: TextStyle(
                        color: _date == null ? Colors.grey : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final p = _priceYuan;
            if (p == null || p <= 0) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请填写成交价')));
              return;
            }
            if (p < 10000) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('金额过低,请确认单位为元')));
              return;
            }
            if (_date == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请选择成交日期')));
              return;
            }
            Navigator.of(context)
                .pop(_LaConfirmResult(p, _dateStr(_date!)));
          },
          child: const Text('提交比对', style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}

class _LaRejectDialog extends StatefulWidget {
  const _LaRejectDialog();

  @override
  State<_LaRejectDialog> createState() => _LaRejectDialogState();
}

class _LaRejectDialogState extends State<_LaRejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动驳回成交确认'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ 驳回用于"根本没这笔成交"等情况。如果只是价格填错,请在独立填价时填写正确价格,系统会自动驳回不一致。',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 100,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '请说明驳回理由',
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
            final t = _controller.text.trim();
            if (t.isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请填写理由')));
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

class _BaUpdateResult {
  final int? priceYuan;
  final String? date;
  final String? notes;
  _BaUpdateResult({this.priceYuan, this.date, this.notes});
}

class _LaUpdateResult {
  final int priceYuan;
  final String date;
  _LaUpdateResult({required this.priceYuan, required this.date});
}

class _LaUpdateDialog extends StatefulWidget {
  final int? currentPrice;
  final String? currentDate;
  const _LaUpdateDialog({this.currentPrice, this.currentDate});

  @override
  State<_LaUpdateDialog> createState() => _LaUpdateDialogState();
}

class _LaUpdateDialogState extends State<_LaUpdateDialog> {
  late final TextEditingController _priceController;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
        text: widget.currentPrice?.toString() ?? '');
    if (widget.currentDate != null) {
      try {
        _date = DateTime.parse(widget.currentDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  int? get _priceYuan =>
      int.tryParse(_priceController.text.trim().isEmpty
          ? '0'
          : _priceController.text.trim());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _dateStr(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _priceYuan;
    final wan =
        (p != null && p > 0) ? (p / 10000).toStringAsFixed(1) : '--';

    return AlertDialog(
      title: const Text('修改我的填报'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ 你看不到 BA 填的价格,系统会独立比对。请如实填写你记录的成交价,单位:元。',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '成交价',
                hintText: '例如 850000',
                suffixText: '元',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('约 $wan 万元',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _date == null ? '选择成交日期' : _dateStr(_date!),
                      style: TextStyle(
                        color: _date == null ? Colors.grey : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final p = _priceYuan;
            if (p == null || p <= 0) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请填写成交价')));
              return;
            }
            if (p < 10000) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('金额过低,请确认单位为元')));
              return;
            }
            if (_date == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请选择成交日期')));
              return;
            }
            Navigator.of(context).pop(_LaUpdateResult(
              priceYuan: p,
              date: _dateStr(_date!),
            ));
          },
          child: const Text('重新提交', style: TextStyle(color: Colors.orange)),
        ),
      ],
    );
  }
}

class _BaUpdateDialog extends StatefulWidget {
  final int? currentPrice;
  final String? currentDate;
  final String? currentNotes;
  const _BaUpdateDialog({
    this.currentPrice,
    this.currentDate,
    this.currentNotes,
  });

  @override
  State<_BaUpdateDialog> createState() => _BaUpdateDialogState();
}

class _BaUpdateDialogState extends State<_BaUpdateDialog> {
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
        text: widget.currentPrice?.toString() ?? '');
    _notesController = TextEditingController(text: widget.currentNotes ?? '');
    if (widget.currentDate != null) {
      try {
        _date = DateTime.parse(widget.currentDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? get _priceYuan => int.tryParse(_priceController.text.trim());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _dateStr(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _priceYuan;
    final wan =
        (p != null && p > 0) ? (p / 10000).toStringAsFixed(1) : '--';

    return AlertDialog(
      title: const Text('修改并重新提交'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '成交价',
                suffixText: '元',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('约 $wan 万元',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _date == null ? '选择成交日期' : _dateStr(_date!),
                      style: TextStyle(
                        color: _date == null ? Colors.grey : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '备注(选填)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final p = _priceYuan;
            if (p == null || p <= 0) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请填写成交价')));
              return;
            }
            if (p < 10000) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('金额过低,请确认单位为元')));
              return;
            }
            if (_date == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请选择成交日期')));
              return;
            }
            Navigator.of(context).pop(_BaUpdateResult(
              priceYuan: p,
              date: _dateStr(_date!),
              notes: _notesController.text.trim(),
            ));
          },
          child:
              const Text('重新提交', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}