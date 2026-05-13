import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/transaction_service.dart';

class TransactionInitiateScreen extends StatefulWidget {
  final String showingId;
  final Map<String, dynamic> snapshot; // listing_snapshot
  final String listingPriceWan; // 房源挂牌价(万元),用作参考

  const TransactionInitiateScreen({
    super.key,
    required this.showingId,
    required this.snapshot,
    required this.listingPriceWan,
  });

  @override
  State<TransactionInitiateScreen> createState() =>
      _TransactionInitiateScreenState();
}

class _TransactionInitiateScreenState extends State<TransactionInitiateScreen> {
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dealDate;
  bool _submitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dealDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: '选择成交日期',
    );
    if (picked != null && mounted) {
      setState(() => _dealDate = picked);
    }
  }

  String _dateStr(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  int? get _priceYuan {
    final s = _priceController.text.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  String get _priceWanPreview {
    final p = _priceYuan;
    if (p == null || p <= 0) return '--';
    final wan = p / 10000.0;
    return wan.toStringAsFixed(1);
  }

  /// 单位防错提示
  String? get _priceWarning {
    final p = _priceYuan;
    if (p == null || p <= 0) return null;
    // 如果 < 10000,可能误填万元数值
    if (p < 10000) {
      return '金额过低,您是否误把"万元"填成"元"?请核对后重试';
    }
    // 如果 > 5 亿,明显错误
    if (p > 500_000_000) return '金额超出合理范围';
    return null;
  }

  Future<void> _submit() async {
    final price = _priceYuan;
    if (price == null || price <= 0) {
      _snack('请填写有效的成交价');
      return;
    }
    if (_priceWarning != null) {
      _snack(_priceWarning!);
      return;
    }
    if (_dealDate == null) {
      _snack('请选择成交日期');
      return;
    }

    // 二次确认弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认发起成交'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请再次核对成交价格:',
                style: TextStyle(color: Colors.grey, fontSize: 12.0)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$price',
                    style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(width: 4),
                const Text('元',
                    style: TextStyle(color: Colors.red, fontSize: 12.0)),
                const SizedBox(width: 12),
                Text('≈ $_priceWanPreview 万元',
                    style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
              ],
            ),
            const SizedBox(height: 12),
            Text('成交日期:${_dateStr(_dealDate!)}',
                style: const TextStyle(fontSize: 12.0)),
            const SizedBox(height: 12),
            const Text(
              '发起后 LA 将独立填价比对。一致则成交生效,不一致将被系统自动驳回,需双方核对后重提。',
              style: TextStyle(color: Colors.grey, fontSize: 11.0),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('返回修改'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认发起', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await TransactionService.instance.initiate(
        showingId: widget.showingId,
        dealPriceYuan: price,
        dealDate: _dateStr(_dealDate!),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('成交确认已提交,等待 LA 独立填价')),
      );
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('提交失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.snapshot;
    final warning = _priceWarning;

    return Scaffold(
      appBar: AppBar(title: const Text('发起成交确认')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 房源快照
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('成交房源',
                      style: TextStyle(color: Colors.grey, fontSize: 11.0)),
                  const SizedBox(height: 6),
                  Text(
                    '${sp['community']} ${sp['building']}号楼${sp['unit']}单元${sp['room_no']}',
                    style: const TextStyle(
                        fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · 挂牌价 ¥${widget.listingPriceWan}万',
                    style: const TextStyle(color: Colors.grey, fontSize: 12.0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 成交价
          const Text('成交价 *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0)),
          const SizedBox(height: 6),
          const Text('请填写实际成交价的**精确数字,单位:元**',
              style: TextStyle(color: Colors.grey, fontSize: 11.0)),
          const SizedBox(height: 10),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '例如 850000',
              suffixText: '元',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 换算预览
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (warning != null ? Colors.red : Colors.blue)
                  .withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              children: [
                Icon(
                  warning != null ? Icons.warning_amber : Icons.info_outline,
                  size: 16,
                  color: warning != null ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warning ??
                        (_priceYuan == null
                            ? '输入成交价后自动换算为万元'
                            : '约 $_priceWanPreview 万元'),
                    style: TextStyle(
                      fontSize: 11.0,
                      color: warning != null ? Colors.red : Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 成交日期
          const Text('成交日期 *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0)),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.grey400),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    _dealDate == null ? '点击选择合同签订日期' : _dateStr(_dealDate!),
                    style: TextStyle(
                      color: _dealDate == null ? Colors.grey : Colors.black,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 备注
          const Text('补充说明(选填)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0)),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '如:全款、付款方式、特殊说明...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // 提醒
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '双方独立填价:发起后 LA 会独立填写自己记录的成交价,系统自动比对,一致才生效。这是交易留痕的核心防伪机制。',
                    style: TextStyle(
                        fontSize: 11.0, color: Colors.black87, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.gavel),
              label: Text(_submitting ? '提交中...' : '发起成交确认',
                  style: const TextStyle(fontSize: AppTheme.fontSectionTitle)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}