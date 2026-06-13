import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

/// 忘记密码 / 重置密码页(未登录)
/// 凭短信验证码重置:send-sms-code → /auth/reset-password → 回登录页。
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirm = TextEditingController();

  bool _sendingSms = false;
  bool _submitting = false;
  bool _obscure = true;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _newPwd.dispose();
    _confirm.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) t.cancel();
      });
    });
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v.trim())) return '手机号格式不正确';
    return null;
  }

  String? _validateCode(String? v) {
    if ((v ?? '').trim().length != 6) return '验证码应为 6 位';
    return null;
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

  Future<void> _sendSmsCode() async {
    final phone = _phone.text.trim();
    if (_validatePhone(phone) != null) {
      _snack('请输入正确的手机号');
      return;
    }
    setState(() => _sendingSms = true);
    try {
      await ApiClient.instance.dio
          .post('/auth/send-sms-code', data: {'phone': phone});
      if (!mounted) return;
      _snack('验证码已发送(开发环境看后端终端)');
      _startCountdown();
    } on DioException catch (e) {
      if (!mounted) return;
      _snack('发送失败: ${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final response = await ApiClient.instance.dio.post(
        '/auth/reset-password',
        data: {
          'phone': _phone.text.trim(),
          'code': _code.text.trim(),
          'new_password': _newPwd.text.trim(),
        },
      );
      if (response.data['success'] == true) {
        if (!mounted) return;
        _snack('密码重置成功,请用新密码登录');
        context.go('/login');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _snack('重置失败: ${_errMsg(e)}');
    } catch (e) {
      if (!mounted) return;
      _snack('重置失败: $e');
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
      appBar: AppBar(title: const Text('忘记密码')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '用注册手机号接收验证码,重置登录密码。',
                  style: TextStyle(fontSize: 12.0, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                // 手机号 + 发码
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: _validatePhone,
                        decoration: const InputDecoration(
                          labelText: '手机号 *',
                          prefixIcon: Icon(Icons.phone_android),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: (_sendingSms || _countdown > 0)
                            ? null
                            : _sendSmsCode,
                        child: _sendingSms
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: _validateCode,
                  decoration: const InputDecoration(
                    labelText: '验证码 *',
                    hintText: '6 位',
                    prefixIcon: Icon(Icons.sms_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPwd,
                  obscureText: _obscure,
                  maxLength: 32,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: '新密码 *',
                    hintText: '6-32 位,含字母和数字',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
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
                        : const Text('重置密码',
                            style: TextStyle(fontSize: 16.0)),
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
