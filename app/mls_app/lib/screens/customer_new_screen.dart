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

/// 添加客户 — 单页表单（买/卖方切换）
class CustomerNewScreen extends StatefulWidget {
  const CustomerNewScreen({super.key});

  @override
  State<CustomerNewScreen> createState() => _CustomerNewScreenState();
}

class _CustomerNewScreenState extends State<CustomerNewScreen> {
  bool _isBuyer = true;
  bool _submitting = false;

  final _surnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  List<String> _layout = ['3室2厅'];
  List<String> _areas = ['桥东', '经开区'];
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  String _intent = '高';
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _surnameCtrl.dispose();
    _phoneCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_surnameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写称呼和手机号')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await CustomerService.instance.create(
        surname: _surnameCtrl.text.trim(),
        gender: _isBuyer ? 'male' : 'female',
        phone: _phoneCtrl.text.trim(),
        requirements: _isBuyer
            ? '意向户型:${_layout.join('/')} 区域:${_areas.join('/')} 预算:${_budgetMinCtrl.text}-${_budgetMaxCtrl.text}万 意向:$_intent'
            : '委托出售:${_layout.join('/')} 区域:${_areas.join('/')} 期望:${_budgetMinCtrl.text}-${_budgetMaxCtrl.text}万',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('客户已建档')),
        );
        context.pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建档失败:${e.message}')),
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
                  MlsFormSection(title: 'CONTACT', children: [
                    MlsField(label: '客户称呼', required: true, child: MlsTextInput(controller: _surnameCtrl, hint: '如 王先生', leading: LucideIcons.user)),
                    MlsField(label: '手机号', required: true, child: MlsTextInput(controller: _phoneCtrl, hint: '13800000000', leading: LucideIcons.phone, mono: true, type: TextInputType.phone)),
                  ]),
                  const SizedBox(height: 24),
                  MlsFormSection(title: _isBuyer ? 'DEMAND · 需求' : 'PROPERTY · 委托', children: [
                    MlsField(label: _isBuyer ? '意向户型' : '房源户型', child: MlsChipSelect<String>(options: const ['1室1厅', '2室1厅', '2室2厅', '3室2厅', '4室2厅'], selected: _layout, multi: true, onChanged: (v) => setState(() => _layout = v as List<String>))),
                    MlsField(label: _isBuyer ? '意向区域' : '所在区域', child: MlsChipSelect<String>(options: const ['桥东', '桥西', '经开区', '高新区', '万达商圈', '学府片区'], selected: _areas, multi: true, onChanged: (v) => setState(() => _areas = v as List<String>))),
                    MlsField(label: _isBuyer ? '预算范围（万）' : '期望售价（万）', child: Row(children: [
                      Expanded(child: MlsTextInput(controller: _budgetMinCtrl, hint: '150', mono: true, suffix: '万')),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('—', style: TextStyle(color: MlsColors.textTertiary))),
                      Expanded(child: MlsTextInput(controller: _budgetMaxCtrl, hint: '250', mono: true, suffix: '万')),
                    ])),
                  ]),
                  const SizedBox(height: 24),
                  MlsFormSection(title: 'FOLLOW-UP', children: [
                    MlsField(label: '意向等级', child: MlsChipSelect<String>(options: const ['高', '中', '低'], selected: _intent, onChanged: (v) => setState(() => _intent = v))),
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
