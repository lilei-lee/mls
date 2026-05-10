import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/customer_service.dart';

/// 新建客户页 · Day 12
class CustomerCreateScreen extends StatefulWidget {
  const CustomerCreateScreen({super.key});

  @override
  State<CustomerCreateScreen> createState() => _CustomerCreateScreenState();
}

class _CustomerCreateScreenState extends State<CustomerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _surname = TextEditingController();
  final _phone = TextEditingController();
  final _requirements = TextEditingController();

  String _gender = 'male';
  bool _submitting = false;

  @override
  void dispose() {
    _surname.dispose();
    _phone.dispose();
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await CustomerService.instance.create(
        surname: _surname.text.trim(),
        gender: _gender,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        requirements: _requirements.text.trim().isEmpty
            ? null
            : _requirements.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('客户已创建')),
      );
      context.pop(true); // 返 true 让列表页刷新
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败:$msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败:$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建客户')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 姓氏
            TextFormField(
              controller: _surname,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: '客户姓氏 *',
                hintText: '如:王',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return '请填写姓氏';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // 性别
            const Text('性别 *',
                style: TextStyle(fontSize: AppTheme.fontBody, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'male',
                    groupValue: _gender,
                    title: const Text('先生'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'female',
                    groupValue: _gender,
                    title: const Text('女士'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 电话
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: '手机号(可选)',
                hintText: '11 位数字',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return null; // 选填
                if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(s)) {
                  return '手机号格式不正确';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // 需求
            TextFormField(
              controller: _requirements,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '购房需求(可选)',
                hintText: '如:两室一厅 · 80-100 万 · 桥东区优先',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存', style: TextStyle(fontSize: AppTheme.fontSectionTitle)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}