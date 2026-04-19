import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

/// 房源编辑页(仅可编辑部分字段,地址不可改)
class ListingEditScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> original;
  const ListingEditScreen({
    super.key,
    required this.listingId,
    required this.original,
  });

  @override
  State<ListingEditScreen> createState() => _ListingEditScreenState();
}

class _ListingEditScreenState extends State<ListingEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _layout;
  late final TextEditingController _floor;
  late final TextEditingController _totalFloor;
  late final TextEditingController _orientation;
  late final TextEditingController _priceWan;
  late final TextEditingController _remarks;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _layout = TextEditingController(text: o['layout']?.toString() ?? '');
    _floor = TextEditingController(text: o['floor']?.toString() ?? '');
    _totalFloor =
        TextEditingController(text: o['total_floor']?.toString() ?? '');
    _orientation =
        TextEditingController(text: o['orientation']?.toString() ?? '');
    _priceWan = TextEditingController(text: o['price_wan']?.toString() ?? '');
    _remarks = TextEditingController(text: o['remarks']?.toString() ?? '');
  }

  @override
  void dispose() {
    _layout.dispose();
    _floor.dispose();
    _totalFloor.dispose();
    _orientation.dispose();
    _priceWan.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await ApiClient.instance.dio.patch(
        '/listings/${widget.listingId}',
        data: {
          'layout': _layout.text.trim(),
          'floor': int.parse(_floor.text),
          'total_floor': int.parse(_totalFloor.text),
          'orientation': _orientation.text.trim(),
          'price_wan': double.parse(_priceWan.text),
          'remarks': _remarks.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label不能为空' : null;

  @override
  Widget build(BuildContext context) {
    final o = widget.original;
    return Scaffold(
      appBar: AppBar(title: const Text('编辑房源')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '地址不可修改:${o['community']} ${o['building']}号楼${o['unit']}单元${o['room_no']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _tf(_layout, '户型', hint: '如:2室1厅1卫'),
            Row(
              children: [
                Expanded(child: _tf(_floor, '所在楼层', numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _tf(_totalFloor, '总楼层', numeric: true)),
              ],
            ),
            _tf(_orientation, '朝向'),
            _tf(_priceWan, '报价(万元)', numeric: true, decimal: true),
            _tf(_remarks, '备注', required: false, maxLines: 3),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    String? hint,
    bool numeric = false,
    bool decimal = false,
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: numeric
            ? TextInputType.numberWithOptions(decimal: decimal)
            : TextInputType.text,
        inputFormatters: numeric
            ? [
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                )
              ]
            : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required ? (v) => _req(v, label) : null,
      ),
    );
  }
}