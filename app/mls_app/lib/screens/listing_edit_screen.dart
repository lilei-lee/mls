import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../widgets/photo_picker.dart';

/// 房源编辑页 - V2.1 #15 段 7.5:物理字段移到辞典,编辑页只改营销字段
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

  late final TextEditingController _orientation;
  late final TextEditingController _priceWan;
  late final TextEditingController _bonusYuan;
  late final TextEditingController _remarks;

  late List<PickedPhoto> _photos;
  String? _coverThumbnail;

  bool _submitting = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _orientation =
        TextEditingController(text: o['orientation']?.toString() ?? '');
    _priceWan = TextEditingController(text: o['price_wan']?.toString() ?? '');
    _bonusYuan = TextEditingController(
        text: (o['bonus_yuan'] ?? 0).toString());
    _remarks = TextEditingController(text: o['remarks']?.toString() ?? '');

    final rawPhotos = (o['photos'] as List?) ?? [];
    _photos = rawPhotos
        .map((e) => PickedPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
    _coverThumbnail = o['cover_thumbnail'] as String?;
  }

  @override
  void dispose() {
    _orientation.dispose();
    _priceWan.dispose();
    _bonusYuan.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final priceVal = double.tryParse(_priceWan.text.trim());
      if (priceVal == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报价格式不正确')),
        );
        return;
      }

      final bonusVal = int.tryParse(_bonusYuan.text.trim()) ?? 0;

      final payload = {
        'orientation': _orientation.text.trim(),
        'price_wan': priceVal,
        'bonus_yuan': bonusVal,
        'remarks': _remarks.text.trim(),
        'cover_thumbnail': _coverThumbnail,
        'photos': _photos.map((p) => p.toJson()).toList(),
      };

      await ApiClient.instance.dio.patch(
        '/listings/${widget.listingId}',
        data: payload,
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

  Future<void> _syncToAuthority() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认采用辞典权威值?'),
        content: const Text(
          '这将提交一条新的物理信息记录,你的旧记录保留为历史。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认同步', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _syncing = true);
    try {
      await ApiClient.instance.dio.post(
        '/listings/${widget.listingId}/sync-physical',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已同步,正在刷新...')),
      );
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('同步失败:$msg')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label不能为空' : null;

  @override
  Widget build(BuildContext context) {
    final o = widget.original;
    final district = o['district'] ?? '其他';
    final address =
        '${o['community']} ${o['building']}号楼${o['unit']}单元${o['room_no']}';

    return Scaffold(
      appBar: AppBar(title: const Text('编辑房源')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BuildSyncBanner(original: o, syncing: _syncing, onSync: _syncToAuthority),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '地址信息不可修改',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$district · $address',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            PhotoPicker(
              initialPhotos: _photos,
              onChanged: (list) => setState(() => _photos = list),
              onCoverThumbnailChanged: (thumb) {
                setState(() => _coverThumbnail = thumb);
              },
            ),
            const SizedBox(height: 20),

            _sectionTitle('户型'),
            _readOnlyField('户型', o['layout'] as String? ?? '户型未知'),
            const SizedBox(height: 20),
            _sectionTitle('楼层与朝向'),
            _tf(_orientation, '朝向'),
            const SizedBox(height: 20),
            _sectionTitle('报价与合作奖金'),
            _tf(_priceWan, '报价(万元)', numeric: true, decimal: true),
            _tf(_bonusYuan, '合作奖金(元)', numeric: true, required: false),
            const Padding(
              padding: EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                '💡 奖金 = 成交后您从中介费里拿出激励 BA 的金额。0 表示无奖金。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            _sectionTitle('备注'),
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

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
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

// ==================== 黄条 widget ====================

class _BuildSyncBanner extends StatelessWidget {
  final Map<String, dynamic> original;
  final bool syncing;
  final VoidCallback onSync;

  const _BuildSyncBanner({
    required this.original,
    required this.syncing,
    required this.onSync,
  });

  static const _fieldLabels = {
    'area_sqm': '面积',
    'floor': '楼层',
    'total_floor': '总楼层',
    'rooms': '卧室数',
    'halls': '客厅数',
    'bathrooms': '卫生间数',
  };

  static const _fieldUnits = {
    'area_sqm': '㎡',
    'floor': '',
    'total_floor': '',
    'rooms': '',
    'halls': '',
    'bathrooms': '',
  };

  @override
  Widget build(BuildContext context) {
    final myClaim = original['my_last_claim'] as Map<String, dynamic>?;
    if (myClaim == null) return const SizedBox.shrink();

    final diffs = <Map<String, dynamic>>[];
    for (final field in _fieldLabels.keys) {
      final authVal = original[field];
      final myVal = myClaim[field];
      if (authVal != null && myVal != null && authVal != myVal) {
        diffs.add({'field': field, 'auth': authVal, 'my': myVal});
      }
    }

    if (diffs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '你提交的物理信息与权威值不符',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final d in diffs)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 28),
              child: Text(
                '${_fieldLabels[d['field']]}: '
                '${d['auth']}${_fieldUnits[d['field']]}(权威) '
                'vs ${d['my']}${_fieldUnits[d['field']]}(你)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: syncing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('一键同步权威值'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
