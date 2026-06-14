import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../services/customer_service.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_primary_button.dart';
import '../widgets/mls/mls_field.dart';
import '../widgets/mls/mls_text_input.dart';
import '../widgets/mls/mls_text_area.dart';
import '../widgets/mls/mls_chip_select.dart';
import '../widgets/mls/mls_big_toggle.dart';
import '../widgets/mls/mls_form_section.dart';

/// 添加客户 — 升级版富表单(结构化档案字段)
class CustomerNewScreen extends StatefulWidget {
  const CustomerNewScreen({super.key});

  @override
  State<CustomerNewScreen> createState() => _CustomerNewScreenState();
}

class _CustomerNewScreenState extends State<CustomerNewScreen> {
  static const _gradeMap = {'高': 'A', '中': 'B', '低': 'C'};

  bool _isBuyer = true;
  bool _submitting = false;

  final _surnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneAltCtrl = TextEditingController();
  final _wechatCtrl = TextEditingController();
  String _gender = 'male';

  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  List<String> _areas = [];
  final _areaNeedCtrl = TextEditingController();
  String? _rooms;
  String? _halls;
  String? _baths;
  String? _purpose;
  String? _payment;
  String? _source;

  String _grade = '中';
  DateTime? _followUp;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _surnameCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneAltCtrl.dispose();
    _wechatCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _areaNeedCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int? _toInt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _followUp = d);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_surnameCtrl.text.trim().isEmpty) {
      _snack('请填写客户称呼');
      return;
    }
    final bmin = _toInt(_budgetMinCtrl);
    final bmax = _toInt(_budgetMaxCtrl);
    if (bmin != null && bmax != null && bmin > bmax) {
      _snack('预算最低不能高于最高');
      return;
    }

    final extra = <String, dynamic>{
      'intent_grade': _gradeMap[_grade],
    };
    if (bmin != null) extra['budget_min_wan'] = bmin;
    if (bmax != null) extra['budget_max_wan'] = bmax;
    if (_areas.isNotEmpty) extra['intent_districts'] = _areas;
    if (_rooms != null) extra['rooms_need'] = int.parse(_rooms!);
    if (_halls != null) extra['halls_need'] = int.parse(_halls!);
    if (_baths != null) extra['baths_need'] = int.parse(_baths!);
    if (_areaNeedCtrl.text.trim().isNotEmpty) {
      extra['area_need'] = _areaNeedCtrl.text.trim();
    }
    if (_purpose != null) extra['purpose'] = _purpose;
    if (_payment != null) extra['payment'] = _payment;
    if (_source != null) extra['source'] = _source;
    if (_wechatCtrl.text.trim().isNotEmpty) {
      extra['wechat'] = _wechatCtrl.text.trim();
    }
    if (_phoneAltCtrl.text.trim().isNotEmpty) {
      extra['phone_alt'] = _phoneAltCtrl.text.trim();
    }
    if (_followUp != null) extra['next_follow_up_at'] = _fmtDate(_followUp!);

    setState(() => _submitting = true);
    try {
      await CustomerService.instance.create(
        surname: _surnameCtrl.text.trim(),
        gender: _gender,
        phone: _phoneCtrl.text.trim(),
        requirements: _noteCtrl.text.trim(),
        extra: extra,
      );
      if (mounted) {
        _snack('客户已建档');
        context.pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        final d = e.response?.data?['detail'];
        _snack('建档失败:${d is String ? d : (e.message ?? '网络错误')}');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: SafeArea(
        child: Column(
          children: [
            MlsNavBar(title: '添加客户'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(children: [
                  MlsBigToggle(
                    left: (icon: Icons.search, label: '买方', sub: '找房需求'),
                    right: (icon: Icons.sell, label: '卖方', sub: '委托出售'),
                    leftAccent: MlsColors.primary,
                    rightAccent: MlsColors.gold,
                    isLeft: _isBuyer,
                    onChanged: (v) => setState(() => _isBuyer = v),
                  ),
                  const SizedBox(height: 24),

                  // 联系
                  MlsFormSection(title: 'CONTACT · 联系', children: [
                    MlsField(label: '客户称呼', required: true, child: MlsTextInput(controller: _surnameCtrl, hint: '如 王先生', leading: LucideIcons.user)),
                    MlsField(label: '手机号', child: MlsTextInput(controller: _phoneCtrl, hint: '13800000000', leading: LucideIcons.phone, mono: true, type: TextInputType.phone)),
                    MlsField(label: '备用电话', child: MlsTextInput(controller: _phoneAltCtrl, hint: '选填', leading: LucideIcons.phone, mono: true, type: TextInputType.phone)),
                    MlsField(label: '微信', child: MlsTextInput(controller: _wechatCtrl, hint: '选填', leading: LucideIcons.messageCircle)),
                    MlsField(label: '性别', child: MlsChipSelect<String>(options: const ['先生', '女士'], selected: _gender == 'male' ? '先生' : '女士', onChanged: (v) => setState(() => _gender = v == '先生' ? 'male' : 'female'))),
                  ]),
                  const SizedBox(height: 24),

                  // 需求
                  MlsFormSection(title: _isBuyer ? 'DEMAND · 购房需求' : 'PROPERTY · 委托', children: [
                    MlsField(label: _isBuyer ? '预算范围（万）' : '期望售价（万）', child: Row(children: [
                      Expanded(child: MlsTextInput(controller: _budgetMinCtrl, hint: '150', mono: true, suffix: '万', type: TextInputType.number)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('—', style: TextStyle(color: MlsColors.textTertiary))),
                      Expanded(child: MlsTextInput(controller: _budgetMaxCtrl, hint: '250', mono: true, suffix: '万', type: TextInputType.number)),
                    ])),
                    MlsField(label: _isBuyer ? '意向区域' : '所在区域', child: MlsChipSelect<String>(options: const ['桥东区', '桥西区', '经开区', '高新区', '宣化区', '下花园区'], selected: _areas, multi: true, onChanged: (v) => setState(() => _areas = v as List<String>))),
                    MlsField(label: '室', child: MlsChipSelect<String>(options: const ['1', '2', '3', '4', '5'], selected: _rooms ?? '', onChanged: (v) => setState(() => _rooms = v))),
                    MlsField(label: '厅', child: MlsChipSelect<String>(options: const ['1', '2', '3'], selected: _halls ?? '', onChanged: (v) => setState(() => _halls = v))),
                    MlsField(label: '卫', child: MlsChipSelect<String>(options: const ['1', '2', '3'], selected: _baths ?? '', onChanged: (v) => setState(() => _baths = v))),
                    MlsField(label: '面积需求', child: MlsTextInput(controller: _areaNeedCtrl, hint: '如 90-110㎡')),
                    MlsField(label: '购房目的', child: MlsChipSelect<String>(options: const ['刚需', '改善', '投资', '婚房', '学区', '养老'], selected: _purpose ?? '', onChanged: (v) => setState(() => _purpose = v))),
                    MlsField(label: '付款方式', child: MlsChipSelect<String>(options: const ['全款', '商贷', '公积金', '组合贷'], selected: _payment ?? '', onChanged: (v) => setState(() => _payment = v))),
                  ]),
                  const SizedBox(height: 24),

                  // 跟进
                  MlsFormSection(title: 'FOLLOW-UP · 跟进', children: [
                    MlsField(label: '意向等级', child: MlsChipSelect<String>(options: const ['高', '中', '低'], selected: _grade, onChanged: (v) => setState(() => _grade = v))),
                    MlsField(label: '客户来源', child: MlsChipSelect<String>(options: const ['门店', '转介绍', '网络', '老客户', '其他'], selected: _source ?? '', onChanged: (v) => setState(() => _source = v))),
                    MlsField(label: '下次跟进', child: InkWell(
                      onTap: _pickFollowUp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: MlsColors.borderLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(LucideIcons.calendar, size: 16, color: MlsColors.textTertiary),
                          const SizedBox(width: 8),
                          Text(_followUp == null ? '未设置(点击选择)' : _fmtDate(_followUp!),
                              style: TextStyle(color: _followUp == null ? MlsColors.textTertiary : MlsColors.textPrimary)),
                        ]),
                      ),
                    )),
                    MlsField(label: '跟进备注', child: MlsTextArea(controller: _noteCtrl, hint: '首次沟通要点...')),
                  ]),
                ]),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MlsColors.bgPageEnd.withValues(alpha: 0.88),
        border: const Border(top: BorderSide(color: MlsColors.borderLight, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: MlsPrimaryButton(
          text: _submitting ? '提交中...' : '建档保存',
          variant: MlsButtonVariant.primary,
          leadingIcon: Icons.how_to_reg,
          size: MlsButtonSize.large,
          fullWidth: true,
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ),
    );
  }
}
