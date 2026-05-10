import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../widgets/photo_picker.dart';
import '../widgets/sale_points_picker.dart';
import '../constants/sale_points_library.dart';

/// V2.2: +4 字段编辑(格局特点 / 卖点标签 / 3 remarks) + 双流程提交
class ListingEditScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> original;
  const ListingEditScreen({super.key, required this.listingId, required this.original});
  @override State<ListingEditScreen> createState() => _ListingEditScreenState();
}

class _ListingEditScreenState extends State<ListingEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // 营销字段
  late final TextEditingController _orientation, _priceWan, _bonusYuan;
  late final TextEditingController _publicRemarks, _agentRemarks, _showingInstructions;
  // 物理字段(Bug B)
  late final TextEditingController _area, _floor, _totalFloor, _rooms, _halls, _bathrooms;

  // V2.2: 格局特点(辞典 claim)
  List<String> _selectedObjectiveFeatures = [];
  String? _selectedDecoration;

  // V2.2: 卖点标签
  List<String> _salePoints = [];

  late List<PickedPhoto> _photos;
  String? _coverThumbnail;
  bool _submitting = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    final mc = (o['my_last_claim'] as Map<String, dynamic>?) ?? {};

    _orientation = TextEditingController(text: o['orientation']?.toString() ?? '');
    _priceWan = TextEditingController(text: o['price_wan']?.toString() ?? '');
    _bonusYuan = TextEditingController(text: (o['bonus_yuan'] ?? 0).toString());

    // V2.2: new remarks
    _publicRemarks = TextEditingController(text: o['public_remarks']?.toString() ?? '');
    _agentRemarks = TextEditingController(text: o['agent_remarks']?.toString() ?? '');
    _showingInstructions = TextEditingController(text: o['showing_instructions']?.toString() ?? '');

    // 预填物理: my_last_claim 优先
    _area = TextEditingController(text: (mc['area_sqm'] ?? o['area_sqm'])?.toString() ?? '');
    _floor = TextEditingController(text: (mc['floor'] ?? o['floor'])?.toString() ?? '');
    _totalFloor = TextEditingController(text: (mc['total_floor'] ?? o['total_floor'])?.toString() ?? '');
    _rooms = TextEditingController(text: (mc['rooms'] ?? o['rooms'])?.toString() ?? '');
    _halls = TextEditingController(text: (mc['halls'] ?? o['halls'])?.toString() ?? '');
    _bathrooms = TextEditingController(text: (mc['bathrooms'] ?? o['bathrooms'])?.toString() ?? '');

    // V2.2: 预填格局特点(my_last_claim 优先,否则 authoritative_attrs / original)
    final mcOf = mc['objective_features'];
    if (mcOf is List) {
      _selectedObjectiveFeatures = List<String>.from(mcOf.cast<String>());
    } else if (o['objective_features'] is List) {
      _selectedObjectiveFeatures = List<String>.from((o['objective_features'] as List).cast<String>());
    }
    _selectedDecoration = (mc['decoration'] ?? o['decoration'])?.toString();

    // V2.2: 预填卖点标签
    if (o['sale_points'] is List) {
      _salePoints = List<String>.from((o['sale_points'] as List).cast<String>());
    }

    final rawPhotos = (o['photos'] as List?) ?? [];
    _photos = rawPhotos.map((e) => PickedPhoto.fromJson(e as Map<String, dynamic>)).toList();
    _coverThumbnail = o['cover_thumbnail'] as String?;
  }

  @override
  void dispose() {
    _orientation.dispose(); _priceWan.dispose(); _bonusYuan.dispose();
    _publicRemarks.dispose(); _agentRemarks.dispose(); _showingInstructions.dispose();
    _area.dispose(); _floor.dispose(); _totalFloor.dispose();
    _rooms.dispose(); _halls.dispose(); _bathrooms.dispose();
    super.dispose();
  }

  // ── 提交 ──
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      // Step A: PATCH 营销字段
      final p = double.tryParse(_priceWan.text.trim());
      if (p == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报价格式不正确')));
        return;
      }
      await ApiClient.instance.dio.patch('/listings/${widget.listingId}', data: {
        'orientation': _orientation.text.trim(),
        'price_wan': p,
        'bonus_yuan': int.tryParse(_bonusYuan.text.trim()) ?? 0,
        'cover_thumbnail': _coverThumbnail,
        'photos': _photos.map((x) => x.toJson()).toList(),
        // V2.2: 4 新字段
        'public_remarks': _publicRemarks.text.trim(),
        'agent_remarks': _agentRemarks.text.trim(),
        'showing_instructions': _showingInstructions.text.trim(),
        'sale_points': _salePoints,
      });

      // Step B: 调 sync-physical(物理 6 + 客观 2)
      final phys = _collectPhysical();
      if (phys.isNotEmpty) {
        phys['force'] = false;
        try {
          await ApiClient.instance.dio.post('/listings/${widget.listingId}/sync-physical', data: phys);
        } on DioException catch (e) {
          if (!mounted) return;
          _handleSyncError(e);
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, dynamic> _collectPhysical() {
    final m = <String, dynamic>{};
    void addInt(TextEditingController c, String key) {
      final v = int.tryParse(c.text.trim());
      if (v != null) m[key] = v;
    }
    final a = double.tryParse(_area.text.trim());
    if (a != null) m['area_sqm'] = a;
    addInt(_floor, 'floor');
    addInt(_totalFloor, 'total_floor');
    addInt(_rooms, 'rooms');
    addInt(_halls, 'halls');
    addInt(_bathrooms, 'bathrooms');
    // V2.2: 客观字段(非 null 才入 body)
    if (_selectedObjectiveFeatures.isNotEmpty) m['objective_features'] = _selectedObjectiveFeatures;
    if (_selectedDecoration != null) m['decoration'] = _selectedDecoration;
    return m;
  }

  void _handleSyncError(DioException e) {
    setState(() => _submitting = false);
    final data = e.response?.data;
    final detail = data is Map ? (data['detail'] ?? '') : '$data';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('物理信息冲突'),
        content: Text('辞典拒绝了你填的值。\n$detail'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('返回修改')),
          TextButton(
            onPressed: () { Navigator.of(ctx).pop(); _forceSubmit(); },
            child: const Text('强制提交我的值', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _forceSubmit() async {
    setState(() => _submitting = true);
    try {
      final phys = _collectPhysical();
      phys['force'] = true;
      await ApiClient.instance.dio.post('/listings/${widget.listingId}/sync-physical', data: phys);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已强制提交,辞典生成 discrepancy 工单')));
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('强制提交失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _syncToAuthority() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认采用辞典权威值?'),
        content: const Text('这将提交一条新的物理信息记录,你的旧记录保留为历史。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确认同步', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _syncing = true);
    try {
      await ApiClient.instance.dio.post('/listings/${widget.listingId}/sync-physical');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已同步,正在刷新...')));
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败:$msg')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label不能为空' : null;

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    final o = widget.original;
    final district = o['district'] ?? '其他';
    final address = '${o['community']} ${o['building']}号楼${o['unit']}单元${o['room_no']}';

    return Scaffold(
      appBar: AppBar(title: const Text('编辑房源')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BuildSyncBanner(original: o, syncing: _syncing, onSync: _syncToAuthority),

            // 地址不可改
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('地址信息不可修改', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$district · $address', style: const TextStyle(fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),

            PhotoPicker(
              initialPhotos: _photos,
              onChanged: (list) => setState(() => _photos = list),
              onCoverThumbnailChanged: (thumb) => setState(() => _coverThumbnail = thumb),
            ),
            const SizedBox(height: 20),

            // 物理字段 6
            _sectionTitle('面积(㎡)'),
            _tf(_area, '面积', numeric: true, decimal: true),
            const SizedBox(height: 20),

            _sectionTitle('楼层'),
            Row(children: [
              Expanded(child: _tf(_floor, '所在楼层', numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_totalFloor, '总楼层', numeric: true)),
            ]),
            const SizedBox(height: 20),

            _sectionTitle('户型'),
            Row(children: [
              Expanded(child: _tf(_rooms, '卧室', numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_halls, '客厅', numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_bathrooms, '卫生间', numeric: true)),
            ]),
            const SizedBox(height: 20),

            // ═══ V2.2 Section 1: 格局特点 ═══
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
            _sectionTitle('卖点标签(营销)'),
            SalePointsPicker(
              initialSelected: _salePoints,
              onChanged: (v) => setState(() => _salePoints = v),
            ),
            const SizedBox(height: 20),

            // ═══ V2.2 Section 3: 房源描述 ═══
            _sectionTitle('房源描述'),
            _tf(_publicRemarks, '公开描述', required: false, maxLines: 3, hint: '所有看房经纪人都能看到'),
            _tf(_agentRemarks, '同行私话', required: false, maxLines: 3, hint: '经纪人间私话,客户看不到'),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text('议价空间 / 业主诚意度 / 内部消息', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
            _tf(_showingInstructions, '看房安排', required: false, maxLines: 2, hint: '申请通过后展示'),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 16),
              child: Text('约看时间 / 业主时段 / 注意事项', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),

            _sectionTitle('朝向'),
            _tf(_orientation, '朝向'),
            const SizedBox(height: 20),

            _sectionTitle('报价与合作奖金'),
            _tf(_priceWan, '报价(万元)', numeric: true, decimal: true),
            _tf(_bonusYuan, '合作奖金(元)', numeric: true, required: false),
            const Padding(
              padding: EdgeInsets.only(bottom: 16, left: 4),
              child: Text('💡 奖金 = 成交后您从中介费里拿出激励 BA 的金额。0 表示无奖金。',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
  );

  Widget _tf(TextEditingController c, String label,
      {String? hint, bool numeric = false, bool decimal = false, bool required = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: numeric ? TextInputType.numberWithOptions(decimal: decimal) : TextInputType.text,
        inputFormatters: numeric ? [FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'))] : null,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
        validator: required ? (v) => _req(v, label) : null,
      ),
    );
  }
}

// ═══════════════════════ 黄条 ═══════════════════════

class _BuildSyncBanner extends StatelessWidget {
  final Map<String, dynamic> original;
  final bool syncing;
  final VoidCallback onSync;
  const _BuildSyncBanner({required this.original, required this.syncing, required this.onSync});

  static const _labels = {
    'area_sqm': '面积', 'floor': '楼层', 'total_floor': '总楼层',
    'rooms': '卧室数', 'halls': '客厅数', 'bathrooms': '卫生间数',
    'objective_features': '客观特征', 'decoration': '装修',
  };
  static const _units = {
    'area_sqm': '㎡', 'floor': '', 'total_floor': '', 'rooms': '', 'halls': '', 'bathrooms': '',
    'objective_features': '', 'decoration': '',
  };

  @override
  Widget build(BuildContext context) {
    final mc = original['my_last_claim'] as Map<String, dynamic>?;
    if (mc == null) return const SizedBox.shrink();

    final diffs = <Map<String, dynamic>>[];
    for (final f in _labels.keys) {
      final a = original[f], m = mc[f];
      if (a != null && m != null && _differs(a, m)) diffs.add({'field': f, 'auth': a, 'my': m});
    }
    if (diffs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade700, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('你提交的物理信息与权威值不符', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        for (final d in diffs)
          Padding(padding: const EdgeInsets.only(bottom: 4, left: 28),
            child: Text('${_labels[d['field']]}: ${_format(d['auth'])}${_units[d['field']]}(权威) vs ${_format(d['my'])}${_units[d['field']]}(你)',
                style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 8),
        Center(child: syncing
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : ElevatedButton.icon(onPressed: onSync, icon: const Icon(Icons.sync, size: 16),
                label: const Text('一键同步权威值'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white))),
      ]),
    );
  }

  static bool _differs(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return true;
      final sa = a.map((e) => e.toString()).toSet();
      final sb = b.map((e) => e.toString()).toSet();
      return !sa.containsAll(sb) || !sb.containsAll(sa);
    }
    return a.toString() != b.toString();
  }

  static String _format(dynamic v) {
    if (v is List) return v.join(', ');
    return v.toString();
  }
}
