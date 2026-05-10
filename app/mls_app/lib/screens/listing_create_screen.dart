import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../services/meta_service.dart';
import '../widgets/photo_picker.dart';
import '../widgets/community_picker.dart';
import '../widgets/sale_points_picker.dart';
import '../constants/sale_points_library.dart';

/// 房源录入页  V2.2: +4 字段(sale_points / 3 remarks / objective_features / decoration)
class ListingCreateScreen extends StatefulWidget {
  const ListingCreateScreen({super.key});

  @override
  State<ListingCreateScreen> createState() => _ListingCreateScreenState();
}

class _ListingCreateScreenState extends State<ListingCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedDistrict;
  PickedCommunity? _pickedCommunity;

  final _building = TextEditingController();
  final _unit = TextEditingController();
  final _roomNo = TextEditingController();

  final _areaSqm = TextEditingController();

  final _rooms = TextEditingController();
  final _halls = TextEditingController();
  final _bathrooms = TextEditingController();

  final _floor = TextEditingController();
  final _totalFloor = TextEditingController();
  final _orientation = TextEditingController(text: '南北通透');

  final _priceWan = TextEditingController();
  final _bonusYuan = TextEditingController(text: '0');

  // V2.2: 3 remarks
  final _publicRemarks = TextEditingController();
  final _agentRemarks = TextEditingController();
  final _showingInstructions = TextEditingController();

  // V2.2: 格局特点(辞典 claim)
  List<String> _selectedObjectiveFeatures = [];
  String? _selectedDecoration;

  // V2.2: 卖点标签
  List<String> _salePoints = [];

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
        setState(() => _loadingDistricts = false);
        _showSnack('加载行政区失败,请刷新');
      }
    }
  }

  @override
  void dispose() {
    _building.dispose(); _unit.dispose(); _roomNo.dispose();
    _areaSqm.dispose(); _rooms.dispose(); _halls.dispose(); _bathrooms.dispose();
    _floor.dispose(); _totalFloor.dispose(); _orientation.dispose();
    _priceWan.dispose(); _bonusYuan.dispose();
    _publicRemarks.dispose(); _agentRemarks.dispose(); _showingInstructions.dispose();
    super.dispose();
  }

  // ── 提交 ──
  Future<void> _submit() async {
    if (_pickedCommunity == null) { _showSnack('请选择或添加小区'); return; }
    if (_selectedDistrict == null) { _showSnack('请选择行政区'); return; }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      // Step A: POST /listings 带所有字段
      final response = await ApiClient.instance.dio.post('/listings', data: {
        'district': _selectedDistrict,
        'community': _pickedCommunity!.name,
        'community_id': _pickedCommunity!.id,
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
        'cover_thumbnail': _coverThumbnail,
        'photos': _photos.map((p) => p.toJson()).toList(),
        // V2.2: 4 新字段
        'sale_points': _salePoints,
        'public_remarks': _publicRemarks.text.trim(),
        'agent_remarks': _agentRemarks.text.trim(),
        'showing_instructions': _showingInstructions.text.trim(),
        'objective_features': _selectedObjectiveFeatures.isNotEmpty ? _selectedObjectiveFeatures : null,
        'decoration': _selectedDecoration,
      });

      final listingId = response.data['listing_id'];

      // Step B: sync-physical (objective_features + decoration)
      // 失败不阻塞 listing 创建
      if (_selectedObjectiveFeatures.isNotEmpty || _selectedDecoration != null) {
        try {
          final syncBody = <String, dynamic>{};
          if (_selectedObjectiveFeatures.isNotEmpty) {
            syncBody['objective_features'] = _selectedObjectiveFeatures;
          }
          if (_selectedDecoration != null) {
            syncBody['decoration'] = _selectedDecoration;
          }
          await ApiClient.instance.dio.post(
            '/listings/$listingId/sync-physical', data: syncBody);
        } catch (_) {
          // sync-physical 失败不阻塞，listing 已创建
        }
      }

      if (mounted) {
        await _showSuccessDialog(
          houseCode: response.data['house_code'],
          listingId: listingId,
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

  Future<void> _showSuccessDialog({required String houseCode, required String listingId}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 60, color: Colors.green),
        title: const Text('录入成功'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('一户一码:'),
          const SizedBox(height: 4),
          SelectableText(houseCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.of(ctx).pop(); _resetForm(); }, child: const Text('继续录入')),
          TextButton(onPressed: () { Navigator.of(ctx).pop(); if (mounted) context.go('/home'); }, child: const Text('返回工作台')),
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
      _selectedObjectiveFeatures = [];
      _selectedDecoration = null;
      _salePoints = [];
    });
    _building.clear(); _unit.clear(); _roomNo.clear(); _areaSqm.clear();
    _rooms.text = ''; _halls.text = ''; _bathrooms.text = '';
    _floor.clear(); _totalFloor.clear(); _priceWan.clear(); _bonusYuan.text = '0';
    _publicRemarks.clear(); _agentRemarks.clear(); _showingInstructions.clear();
  }

  Future<void> _showDuplicateDialog(dynamic detail) async {
    final message = detail is Map ? detail['message'] : '该房源已被录入';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.orange),
        title: const Text('房源已被录入'),
        content: Text('$message\n\n根据"一户一码"规则,同一套房源只能由一位经纪人录入为卖方房源。'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('知道了'))],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label不能为空';
    return null;
  }

  // ════════════════ UI ════════════════

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
                  CommunityPicker(
                    initial: _pickedCommunity,
                    districts: _districts,
                    onChanged: (picked) {
                      setState(() {
                        _pickedCommunity = picked;
                        _selectedDistrict = picked.district;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: const InputDecoration(
                        labelText: '行政区', border: OutlineInputBorder(), isDense: true,
                        prefixIcon: Icon(Icons.location_on_outlined),
                        helperText: '选择小区后自动回填,可修改',
                      ),
                      items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (value) => setState(() => _selectedDistrict = value),
                    ),
                  ),
                  Row(children: [
                    Expanded(child: _textField(_building, '楼号', hint: '3')),
                    const SizedBox(width: 12),
                    Expanded(child: _textField(_unit, '单元', hint: '2')),
                    const SizedBox(width: 12),
                    Expanded(child: _textField(_roomNo, '门牌号', hint: '502')),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle('户型'),
                  Row(children: [
                    Expanded(child: _textField(_rooms, '卧室', numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _textField(_halls, '客厅', numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _textField(_bathrooms, '卫生间', numeric: true)),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle('房源信息'),
                  Row(children: [
                    Expanded(child: _textField(_areaSqm, '建筑面积(㎡)', hint: '89.5', numeric: true, allowDecimal: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _textField(_orientation, '朝向')),
                  ]),
                  Row(children: [
                    Expanded(child: _textField(_floor, '所在楼层', hint: '5', numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _textField(_totalFloor, '总楼层', hint: '18', numeric: true)),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle('报价与合作奖金'),
                  _textField(_priceWan, '报价(万元)', hint: '88.8', numeric: true, allowDecimal: true),
                  _textField(_bonusYuan, '合作奖金(元)', hint: '0 表示无奖金', numeric: true, required: false),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16, left: 4),
                    child: Text('💡 奖金 = 成交后您从中介费里拿出激励 BA 的金额,鼓励同行优先带客。示例:2000-5000 元',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),

                  // ═══ V2.2 Section 1: 格局特点(辞典 claim) ═══
                  _sectionTitle('格局特点(客观,辞典存档)'),
                  const Text('客观特征(可多选)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8, runSpacing: 4,
                    children: SalePointsLibrary.objectiveFeatures.map((f) {
                      final sel = _selectedObjectiveFeatures.contains(f);
                      return FilterChip(
                        label: Text(f, style: TextStyle(fontSize: 13)),
                        selected: sel,
                        onSelected: (_) {
                          setState(() {
                            if (sel) { _selectedObjectiveFeatures.remove(f); }
                            else { _selectedObjectiveFeatures.add(f); }
                          });
                        },
                        selectedColor: Colors.blue.shade50,
                        checkmarkColor: Colors.blue,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('装修情况(单选)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8, runSpacing: 4,
                    children: SalePointsLibrary.decorationOptions.map((d) {
                      final sel = _selectedDecoration == d;
                      return ChoiceChip(
                        label: Text(d, style: TextStyle(fontSize: 13)),
                        selected: sel,
                        onSelected: (_) {
                          setState(() => _selectedDecoration = sel ? null : d);
                        },
                        selectedColor: Colors.blue.shade50,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ═══ V2.2 Section 2: 卖点标签 ═══
                  _sectionTitle('卖点标签(营销,可不选)'),
                  SalePointsPicker(
                    initialSelected: _salePoints,
                    onChanged: (v) => setState(() => _salePoints = v),
                  ),
                  const SizedBox(height: 20),

                  // ═══ V2.2 Section 3: 房源描述 ═══
                  _sectionTitle('房源描述'),
                  _textField(_publicRemarks, '公开描述', required: false, maxLines: 3,
                      hint: '所有看房经纪人都能看到'),
                  _textField(_agentRemarks, '同行私话', required: false, maxLines: 3,
                      hint: '经纪人间私话,客户看不到'),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('议价空间 / 业主诚意度 / 内部消息', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  _textField(_showingInstructions, '看房安排', required: false, maxLines: 2,
                      hint: '申请通过后展示'),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 16),
                    child: Text('约看时间 / 业主时段 / 注意事项', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),

                  PhotoPicker(
                    initialPhotos: _photos,
                    onChanged: (list) => setState(() => _photos = list),
                    onCoverThumbnailChanged: (thumb) => setState(() => _coverThumbnail = thumb),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('提交', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
  );

  Widget _textField(TextEditingController controller, String label,
      {String? hint, bool numeric = false, bool allowDecimal = false, bool required = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.numberWithOptions(decimal: allowDecimal) : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'))]
            : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true,
        ),
        validator: required ? (v) => _required(v, label) : null,
      ),
    );
  }
}
