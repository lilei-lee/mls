import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../widgets/photo_picker.dart';

/// 房源编辑页 - 地址和行政区不可改,可以改户型、楼层、报价、照片等
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

  late final TextEditingController _rooms;
  late final TextEditingController _halls;
  late final TextEditingController _bathrooms;
  late final TextEditingController _floor;
  late final TextEditingController _totalFloor;
  late final TextEditingController _orientation;
  late final TextEditingController _priceWan;
  late final TextEditingController _remarks;

  late List<PickedPhoto> _photos;
  String? _coverThumbnail;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _rooms = TextEditingController(text: (o['rooms'] ?? 0).toString());
    _halls = TextEditingController(text: (o['halls'] ?? 0).toString());
    _bathrooms =
        TextEditingController(text: (o['bathrooms'] ?? 0).toString());
    _floor = TextEditingController(text: o['floor']?.toString() ?? '');
    _totalFloor =
        TextEditingController(text: o['total_floor']?.toString() ?? '');
    _orientation =
        TextEditingController(text: o['orientation']?.toString() ?? '');
    _priceWan = TextEditingController(text: o['price_wan']?.toString() ?? '');
    _remarks = TextEditingController(text: o['remarks']?.toString() ?? '');

    // 段 8:初始化照片列表(从详情里读 photos 数组)
    final rawPhotos = (o['photos'] as List?) ?? [];
    _photos = rawPhotos
        .map((e) => PickedPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
    _coverThumbnail = o['cover_thumbnail'] as String?;
  }

  @override
  void dispose() {
    _rooms.dispose();
    _halls.dispose();
    _bathrooms.dispose();
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
      final roomsVal = int.tryParse(_rooms.text.trim());
      final hallsVal = int.tryParse(_halls.text.trim());
      final bathroomsVal = int.tryParse(_bathrooms.text.trim());
      final floorVal = int.tryParse(_floor.text.trim());
      final totalFloorVal = int.tryParse(_totalFloor.text.trim());
      final priceVal = double.tryParse(_priceWan.text.trim());

      if (roomsVal == null ||
          hallsVal == null ||
          bathroomsVal == null ||
          floorVal == null ||
          totalFloorVal == null ||
          priceVal == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有字段格式不正确,请检查')),
        );
        return;
      }

      final payload = {
        'rooms': roomsVal,
        'halls': hallsVal,
        'bathrooms': bathroomsVal,
        'floor': floorVal,
        'total_floor': totalFloorVal,
        'orientation': _orientation.text.trim(),
        'price_wan': priceVal,
        'remarks': _remarks.text.trim(),
        // 段 8
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

            // 段 8:照片选择器(在最前面,用户最关注)
            PhotoPicker(
              initialPhotos: _photos,
              onChanged: (list) => setState(() => _photos = list),
              onCoverThumbnailChanged: (thumb) {
                setState(() => _coverThumbnail = thumb);
              },
            ),
            const SizedBox(height: 20),

            _sectionTitle('户型'),
            Row(
              children: [
                Expanded(child: _tf(_rooms, '卧室', numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _tf(_halls, '客厅', numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _tf(_bathrooms, '卫生间', numeric: true)),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('楼层与朝向'),
            Row(
              children: [
                Expanded(child: _tf(_floor, '所在楼层', numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _tf(_totalFloor, '总楼层', numeric: true)),
              ],
            ),
            _tf(_orientation, '朝向'),
            const SizedBox(height: 20),
            _sectionTitle('报价'),
            _tf(_priceWan, '报价(万元)', numeric: true, decimal: true),
            const SizedBox(height: 20),
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