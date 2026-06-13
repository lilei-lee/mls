import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

/// 修改 / 设置密码页(已登录)
/// 调 /auth/set-password。已有密码时需填原密码;首次设置可留空。
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirm = TextEditingController();

  bool _submitting = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldPwd.dispose();
    _newPwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '请输入新密码';
    if (s.length < 6 || s.length > 32) return '密码需 6-32 位';
    if (s.contains(RegExp(r'\s'))) return '密码不能包含空格';
    if (!s.contains(RegExp(r'[A-Za-z]')) || !s.contains(RegExp(r'\d'))) {
      return '密码需同时含字母和数字';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').trim() != _newPwd.text.trim()) return '两次输入的密码不一致';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{'new_password': _newPwd.text.trim()};
      final old = _oldPwd.text.trim();
      if (old.isNotEmpty) body['old_password'] = old;

      final response =
          await ApiClient.instance.dio.post('/auth/set-password', data: body);
      if (response.data['success'] == true) {
        if (!mounted) return;
        _snack('密码设置成功');
        context.pop();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _snack('设置失败: ${_errMsg(e)}');
    } catch (e) {
      if (!mounted) return;
      _snack('设置失败: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errMsg(DioException e) {
    final d = e.response?.data?['detail'];
    if (d is String) return d;
    if (d is List && d.isNotEmpty && d.first is Map) {
      return '${d.first['msg'] ?? '参数错误'}';
    }
    return e.message ?? '网络错误';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '首次设置密码可不填原密码;已设过密码则需验证原密码。',
                  style: TextStyle(fontSize: 12.0, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _oldPwd,
                  obscureText: _obscureOld,
                  decoration: InputDecoration(
                    labelText: '原密码(首次设置可留空)',
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOld
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureOld = !_obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPwd,
                  obscureText: _obscureNew,
                  maxLength: 32,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: '新密码 *',
                    hintText: '6-32 位,含字母和数字',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscureNew,
                  maxLength: 32,
                  validator: _validateConfirm,
                  decoration: const InputDecoration(
                    labelText: '确认新密码 *',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('保存', style: TextStyle(fontSize: 16.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
