import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../services/meta_service.dart';
import '../widgets/photo_picker.dart';
import '../widgets/community_picker.dart';

/// 房源录入页
class ListingCreateScreen extends StatefulWidget {
  const ListingCreateScreen({super.key});

  @override
  State<ListingCreateScreen> createState() => _ListingCreateScreenState();
}

class _ListingCreateScreenState extends State<ListingCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedDistrict;
  PickedCommunity? _pickedCommunity;  // V4:从小区库选的小区

  final _building = TextEditingController();
  final _unit = TextEditingController();
  final _roomNo = TextEditingController();

  final _areaSqm = TextEditingController();

  final _rooms = TextEditingController(text: '2');
  final _halls = TextEditingController(text: '1');
  final _bathrooms = TextEditingController(text: '1');

  final _floor = TextEditingController();
  final _totalFloor = TextEditingController();
  final _orientation = TextEditingController(text: '南北通透');

  final _priceWan = TextEditingController();
  final _bonusYuan = TextEditingController(text: '0');
  final _remarks = TextEditingController();

  List<PickedPhoto> _photos = [];
  String? _coverThumbnail;

  bool _submitting = false;

  List<String> _districts = [];
  bool _loadingDistricts = true;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    try {
      final list = await MetaService.instance.getDistricts();
      if (mounted) {
        setState(() {
          _districts = list;
          _loadingDistricts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingDistricts = false;
        });
        _showSnack('加载行政区失败,请刷新');
      }
    }
  }

  @override
  void dispose() {
    _building.dispose();
    _unit.dispose();
    _roomNo.dispose();
    _areaSqm.dispose();
    _rooms.dispose();
    _halls.dispose();
    _bathrooms.dispose();
    _floor.dispose();
    _totalFloor.dispose();
    _orientation.dispose();
    _priceWan.dispose();
    _bonusYuan.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pickedCommunity == null) {
      _showSnack('请选择或添加小区');
      return;
    }
    if (_selectedDistrict == null) {
      _showSnack('请选择行政区');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final response = await ApiClient.instance.dio.post(
        '/listings',
        data: {
          'district': _selectedDistrict,
          'community': _pickedCommunity!.name,
          'community_id': _pickedCommunity!.id,  // V4:关联小区库
          'building': _building.text.trim(),
          'unit': _unit.text.trim(),
          'room_no': _roomNo.text.trim(),
          'area_sqm': double.parse(_areaSqm.text),
          'rooms': int.parse(_rooms.text),
          'halls': int.parse(_halls.text),
          'bathrooms': int.parse(_bathrooms.text),
          'floor': int.parse(_floor.text),
          'total_floor': int.parse(_totalFloor.text),
          'orientation': _orientation.text.trim(),
          'price_wan': double.parse(_priceWan.text),
          'bonus_yuan': int.tryParse(_bonusYuan.text.trim()) ?? 0,
          'remarks': _remarks.text.trim(),
          'cover_thumbnail': _coverThumbnail,
          'photos': _photos.map((p) => p.toJson()).toList(),
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
        await _showDuplicateDialog(e.response?.data?['detail']);
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
              _resetForm();
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

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedDistrict = null;
      _pickedCommunity = null;
      _photos = [];
      _coverThumbnail = null;
    });
    _building.clear();
    _unit.clear();
    _roomNo.clear();
    _areaSqm.clear();
    _rooms.text = '2';
    _halls.text = '1';
    _bathrooms.text = '1';
    _floor.clear();
    _totalFloor.clear();
    _priceWan.clear();
    _bonusYuan.text = '0';
    _remarks.clear();
  }

  Future<void> _showDuplicateDialog(dynamic detail) async {
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

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label不能为空';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录入房源')),
      body: _loadingDistricts
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('地址信息'),

                  // V4:小区选择器(替代原来的小区名输入框)
                  CommunityPicker(
                    initial: _pickedCommunity,
                    districts: _districts,
                    onChanged: (picked) {
                      setState(() {
                        _pickedCommunity = picked;
                        // 选小区时自动回填行政区
                        _selectedDistrict = picked.district;
                      });
                    },
                  ),

                  // 行政区(选了小区会自动回填,但仍可改)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: const InputDecoration(
                        labelText: '行政区',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.location_on_outlined),
                        helperText: '选择小区后自动回填,可修改',
                      ),
                      items: _districts
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDistrict = value;
                        });
                      },
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(child: _textField(_building, '楼号', hint: '3')),
                      const SizedBox(width: 12),
                      Expanded(child: _textField(_unit, '单元', hint: '2')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _textField(_roomNo, '门牌号', hint: '502')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('户型'),
                  Row(
                    children: [
                      Expanded(child: _textField(_rooms, '卧室', numeric: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _textField(_halls, '客厅', numeric: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _textField(_bathrooms, '卫生间', numeric: true)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('房源信息'),
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
                  _sectionTitle('报价与合作奖金'),
                  _textField(
                    _priceWan,
                    '报价(万元)',
                    hint: '88.8',
                    numeric: true,
                    allowDecimal: true,
                  ),
                  _textField(
                    _bonusYuan,
                    '合作奖金(元)',
                    hint: '0 表示无奖金',
                    numeric: true,
                    required: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16, left: 4),
                    child: Text(
                      '💡 奖金 = 成交后您从中介费里拿出激励 BA 的金额,鼓励同行优先带客。示例:2000-5000 元',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),

                  PhotoPicker(
                    initialPhotos: _photos,
                    onChanged: (list) => setState(() => _photos = list),
                    onCoverThumbnailChanged: (thumb) {
                      setState(() => _coverThumbnail = thumb);
                    },
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('备注'),
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
                  allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
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