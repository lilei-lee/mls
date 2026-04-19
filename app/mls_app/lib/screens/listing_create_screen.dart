import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

/// 房源录入页
class ListingCreateScreen extends StatefulWidget {
  const ListingCreateScreen({super.key});

  @override
  State<ListingCreateScreen> createState() => _ListingCreateScreenState();
}

class _ListingCreateScreenState extends State<ListingCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // 所有字段的输入控制器
  final _community = TextEditingController();
  final _building = TextEditingController();
  final _unit = TextEditingController();
  final _roomNo = TextEditingController();
  final _areaSqm = TextEditingController();
  final _layout = TextEditingController();
  final _floor = TextEditingController();
  final _totalFloor = TextEditingController();
  final _orientation = TextEditingController(text: '南北通透');
  final _priceWan = TextEditingController();
  final _remarks = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _community.dispose();
    _building.dispose();
    _unit.dispose();
    _roomNo.dispose();
    _areaSqm.dispose();
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
      final response = await ApiClient.instance.dio.post(
        '/listings',
        data: {
          'community': _community.text.trim(),
          'building': _building.text.trim(),
          'unit': _unit.text.trim(),
          'room_no': _roomNo.text.trim(),
          'area_sqm': double.parse(_areaSqm.text),
          'layout': _layout.text.trim(),
          'floor': int.parse(_floor.text),
          'total_floor': int.parse(_totalFloor.text),
          'orientation': _orientation.text.trim(),
          'price_wan': double.parse(_priceWan.text),
          'remarks': _remarks.text.trim(),
        },
      );

      final data = response.data;
      if (mounted) {
        await _showSuccessDialog(
          houseCode: data['house_code'],
          listingId: data['listing_id'],
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        // 一户一码查重失败
        final detail = e.response?.data?['detail'];
        await _showDuplicateDialog(detail);
      } else {
        final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
        _showSnack('录入失败:$msg');
      }
    } catch (e) {
      if (mounted) _showSnack('录入失败:$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog({
    required String houseCode,
    required String listingId,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 60, color: Colors.green),
        title: const Text('录入成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('一户一码:'),
            const SizedBox(height: 4),
            SelectableText(
              houseCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 继续录入:清空表单
              _formKey.currentState?.reset();
              _community.clear();
              _building.clear();
              _unit.clear();
              _roomNo.clear();
              _areaSqm.clear();
              _layout.clear();
              _floor.clear();
              _totalFloor.clear();
              _priceWan.clear();
              _remarks.clear();
            },
            child: const Text('继续录入'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.go('/home');
            },
            child: const Text('返回工作台'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDuplicateDialog(dynamic detail) async {
    final existingName = detail is Map ? detail['existing_agent_name'] : '其他经纪人';
    final message = detail is Map ? detail['message'] : '该房源已被录入';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            size: 60, color: Colors.orange),
        title: const Text('房源已被录入'),
        content: Text('$message\n\n根据"一户一码"规则,同一套房源只能由一位经纪人录入为卖方房源。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  /// 通用字段校验:不能为空
  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label不能为空';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录入房源')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('地址信息'),
            _textField(_community, '小区名', hint: '如:新华家园'),
            Row(
              children: [
                Expanded(child: _textField(_building, '楼号', hint: '如:3')),
                const SizedBox(width: 12),
                Expanded(child: _textField(_unit, '单元', hint: '如:2')),
                const SizedBox(width: 12),
                Expanded(child: _textField(_roomNo, '门牌号', hint: '如:502')),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('房源信息'),
            _textField(_layout, '户型', hint: '如:2室1厅1卫'),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _areaSqm,
                    '建筑面积(㎡)',
                    hint: '89.5',
                    numeric: true,
                    allowDecimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _textField(_orientation, '朝向')),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _floor,
                    '所在楼层',
                    hint: '5',
                    numeric: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    _totalFloor,
                    '总楼层',
                    hint: '18',
                    numeric: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('报价'),
            _textField(
              _priceWan,
              '报价(万元)',
              hint: '88.8',
              numeric: true,
              allowDecimal: true,
            ),
            const SizedBox(height: 20),
            _sectionTitle('其他'),
            _textField(
              _remarks,
              '备注',
              required: false,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
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
                    : const Text('提交', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    bool numeric = false,
    bool allowDecimal = false,
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? TextInputType.numberWithOptions(decimal: allowDecimal)
            : TextInputType.text,
        inputFormatters: numeric
            ? [
                FilteringTextInputFormatter.allow(
                  allowDecimal
                      ? RegExp(r'[0-9.]')
                      : RegExp(r'[0-9]'),
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
        validator: required ? (v) => _required(v, label) : null,
      ),
    );
  }
}