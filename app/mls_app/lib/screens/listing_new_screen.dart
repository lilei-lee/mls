import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_client.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_step_bar.dart';
import '../widgets/mls/mls_field.dart';
import '../widgets/mls/mls_text_input.dart';
import '../widgets/mls/mls_text_area.dart';
import '../widgets/mls/mls_select_row.dart';
import '../widgets/mls/mls_chip_select.dart';
import '../widgets/mls/mls_form_section.dart';

/// 挂新房源 — 4 步表单
class ListingNewScreen extends StatefulWidget {
  const ListingNewScreen({super.key});

  @override
  State<ListingNewScreen> createState() => _ListingNewScreenState();
}

class _ListingNewScreenState extends State<ListingNewScreen> {
  int _step = 0;
  static const _steps = [
    MlsStepBarItem(label: '基本信息'),
    MlsStepBarItem(label: '户型规格'),
    MlsStepBarItem(label: '价格'),
    MlsStepBarItem(label: '图片'),
  ];

  // Step 0
  final _communityCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  String _orientation = '南北通透';

  // Step 1
  String _layout = '3室2厅';
  final _areaCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _totalFloorCtrl = TextEditingController();
  String _decoration = '精装修';
  final _yearCtrl = TextEditingController();

  // Step 2
  final _priceCtrl = TextEditingController();
  List<String> _tags = ['满五唯一'];
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _communityCtrl.dispose();
    _buildingCtrl.dispose();
    _unitCtrl.dispose();
    _roomCtrl.dispose();
    _areaCtrl.dispose();
    _floorCtrl.dispose();
    _totalFloorCtrl.dispose();
    _yearCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? get _unitPriceHint {
    final area = double.tryParse(_areaCtrl.text);
    final price = double.tryParse(_priceCtrl.text);
    if (area != null && price != null && area > 0) {
      return '单价约 ¥${(price * 10000 / area).round()}/㎡';
    }
    return null;
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _prev() => setState(() => _step = (_step - 1).clamp(0, 3));

  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final area = double.tryParse(_areaCtrl.text) ?? 0;
      final floor = int.tryParse(_floorCtrl.text) ?? 1;
      final totalFloor = int.tryParse(_totalFloorCtrl.text) ?? 1;
      final price = double.tryParse(_priceCtrl.text) ?? 0;
      final year = int.tryParse(_yearCtrl.text);

      await ApiClient.instance.dio.post('/listings', data: {
        'community': _communityCtrl.text.trim(),
        'building': _buildingCtrl.text.trim(),
        'unit': _unitCtrl.text.trim(),
        'room_no': _roomCtrl.text.trim(),
        'orientation': _orientation,
        'area_sqm': area,
        'floor': floor,
        'total_floor': totalFloor,
        'price_wan': price,
        'rooms': 3,
        'bathrooms': 2,
        if (year != null) 'build_year': year,
        'sale_points': _tags,
        'public_remarks': _descCtrl.text.trim(),
        'decoration': _decoration,
        'layout': _layout,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('房源已提交挂牌')),
        );
        Navigator.maybePop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败:${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: SafeArea(
        child: Column(
          children: [
            MlsNavBar(
              title: '挂新房源',
              sub: 'STEP ${_step + 1} / ${_steps.length}',
              onBack: _step > 0 ? _prev : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
              child: MlsStepBar(steps: _steps, current: _step),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _buildStep(),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return MlsFormSection(title: 'LOCATION · 位置', children: [
          MlsField(label: '小区名称', required: true, child: MlsTextInput(controller: _communityCtrl, hint: '如 万达华府', leading: LucideIcons.building, onChanged: (_) => setState(() {}))),
          Row(children: [
            Expanded(child: MlsField(label: '楼栋', child: MlsTextInput(controller: _buildingCtrl, hint: '3', mono: true, suffix: '栋'))),
            const SizedBox(width: 10),
            Expanded(child: MlsField(label: '单元', child: MlsTextInput(controller: _unitCtrl, hint: '2', mono: true, suffix: '单元'))),
            const SizedBox(width: 10),
            Expanded(child: MlsField(label: '房号', child: MlsTextInput(controller: _roomCtrl, hint: '1801', mono: true))),
          ]),
          MlsField(label: '朝向', child: MlsChipSelect<String>(options: const ['南北通透', '朝南', '朝东', '东南', '朝北'], selected: _orientation, onChanged: (v) => setState(() => _orientation = v))),
        ]);
      case 1:
        return MlsFormSection(title: 'SPEC · 户型规格', children: [
          MlsField(label: '户型', child: MlsChipSelect<String>(options: const ['1室1厅', '2室1厅', '2室2厅', '3室2厅', '4室2厅'], selected: _layout, onChanged: (v) => setState(() => _layout = v))),
          MlsField(label: '建筑面积', required: true, child: MlsTextInput(controller: _areaCtrl, hint: '108', mono: true, suffix: '㎡')),
          Row(children: [
            Expanded(child: MlsField(label: '所在楼层', child: MlsTextInput(controller: _floorCtrl, hint: '18', mono: true, suffix: '层'))),
            const SizedBox(width: 10),
            Expanded(child: MlsField(label: '总楼层', child: MlsTextInput(controller: _totalFloorCtrl, hint: '32', mono: true, suffix: '层'))),
          ]),
          Row(children: [
            Expanded(child: MlsField(label: '装修', child: MlsSelectRow(placeholder: '选择装修', value: _decoration, onTap: () => _showDecorationPicker()))),
            const SizedBox(width: 10),
            Expanded(child: MlsField(label: '建成年代', child: MlsTextInput(controller: _yearCtrl, hint: '2015', mono: true))),
          ]),
        ]);
      case 2:
        return MlsFormSection(title: 'PRICE · 价格与亮点', children: [
          MlsField(label: '挂牌总价', required: true, hint: _unitPriceHint, child: MlsTextInput(controller: _priceCtrl, hint: '218', mono: true, suffix: '万', onChanged: (_) => setState(() {}))),
          MlsField(label: '房源亮点', hint: '多选', child: MlsChipSelect<String>(options: const ['满五唯一', '满二', '南北通透', '精装', '近地铁', '学区', '河景', '高楼层', '急售'], selected: _tags, multi: true, onChanged: (v) => setState(() => _tags = v as List<String>))),
          MlsField(label: '补充描述', child: MlsTextArea(controller: _descCtrl, hint: '房源补充描述...')),
        ]);
      case 3:
        return MlsFormSection(title: 'PHOTOS · 图片', children: [
          Row(children: [
            _photoSlot(),
            const SizedBox(width: 10),
            _photoSlot(),
            const SizedBox(width: 10),
            _photoSlot(),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: MlsColors.primaryBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(LucideIcons.info, size: 16, color: MlsColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('建议 ≥6 张实拍图，含客厅/厨房/主卧/次卧/卫生间/阳台', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 12, color: MlsColors.primary))),
            ]),
          ),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _photoSlot() {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: MlsColors.borderStrong, width: 1, strokeAlign: BorderSide.strokeAlignInside),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.photo_camera, size: 28, color: MlsColors.textTertiary),
            const SizedBox(height: 4),
            Text('添加', style: TextStyle(fontFamilyFallback: MlsTypography.sansFallback, fontSize: 11, color: MlsColors.textTertiary)),
          ]),
        ),
      ),
    );
  }

  void _showDecorationPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final d in ['毛坯', '简装', '中装', '精装修', '豪装'])
            ListTile(title: Text(d), onTap: () { setState(() => _decoration = d); Navigator.pop(ctx); }),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _step == 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MlsColors.bgPageEnd.withValues(alpha: 0.88),
        border: const Border(top: BorderSide(color: MlsColors.borderLight, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (_step > 0) ...[
            Expanded(
              child: MlsPrimaryButton(
                text: '上一步', variant: MlsButtonVariant.secondary,
                fullWidth: true, onPressed: _prev,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: MlsPrimaryButton(
              text: isLast ? (_submitting ? '提交中...' : '提交挂牌') : '下一步',
              variant: MlsButtonVariant.primary,
              leadingIcon: isLast ? Icons.check : Icons.arrow_forward,
              fullWidth: true,
              loading: isLast && _submitting,
              onPressed: isLast && _submitting ? null : _next,
            ),
          ),
        ]),
      ),
    );
  }
}
