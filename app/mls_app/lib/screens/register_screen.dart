import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

/// 经纪人注册页
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _idCard = TextEditingController();
  final _storeName = TextEditingController();

  bool _sendingSms = false;
  bool _submitting = false;

  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    _idCard.dispose();
    _storeName.dispose();
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

  Future<void> _sendSmsCode() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _snack('请输入正确的手机号');
      return;
    }
    setState(() => _sendingSms = true);
    try {
      await ApiClient.instance.dio.post(
        '/auth/send-sms-code',
        data: {'phone': phone},
      );
      if (!mounted) return;
      _snack('验证码已发送(开发环境看后端终端)');
      _startCountdown();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('发送失败:$msg');
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      // 注册接口现在直接返回 token(一步到位)
      final response = await ApiClient.instance.dio.post(
        '/auth/register',
        data: {
          'phone': _phone.text.trim(),
          'code': _code.text.trim(),
          'name': _name.text.trim(),
          'id_card': _idCard.text.trim(),
          'store_name': _storeName.text.trim(),
        },
      );

      final data = response.data;
      if (data['success'] == true) {
        // 存 token
        final storage = FlutterSecureStorage();
        await storage.write(key: 'access_token', value: data['access_token']);
        await storage.write(key: 'refresh_token', value: data['refresh_token']);
        await storage.write(key: 'agent_id', value: data['agent_id']);
        await storage.write(key: 'name', value: data['name']);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('注册成功,欢迎 ${data['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );
        context.go('/home?name=${Uri.encodeComponent(data['name'])}');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = '网络错误';
      final d = e.response?.data?['detail'];
      if (d is String) {
        msg = d;
      } else if (d is List && d.isNotEmpty) {
        final first = d.first;
        if (first is Map) {
          msg = '字段 ${first['loc']?.last ?? '?'} ${first['msg'] ?? ''}';
        }
      } else {
        msg = e.message ?? '网络错误';
      }
      _snack('注册失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label不能为空';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v.trim())) return '手机号格式不正确';
    return null;
  }

  String? _validateCode(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入验证码';
    if (v.trim().length != 6) return '验证码应为 6 位数字';
    return null;
  }

  String? _validateIdCard(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入身份证号';
    final s = v.trim().toUpperCase();
    // 简单校验:18 位,前 17 位数字,末位数字或 X
    if (!RegExp(r'^\d{17}[\dX]$').hasMatch(s)) {
      return '身份证号格式不正确';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('经纪人注册')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.home_work, size: 58, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text(
                    '加入 MLS 经纪人平台',
                    style: TextStyle(
                      fontSize: AppTheme.fontAppBar,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '让每一次成交都留痕',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 姓名
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '姓名',
                hintText: '真实姓名',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => _required(v, '姓名'),
            ),
            const SizedBox(height: 16),

            // 身份证
            TextFormField(
              controller: _idCard,
              keyboardType: TextInputType.visiblePassword,
              inputFormatters: [
                LengthLimitingTextInputFormatter(18),
                FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
              ],
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '身份证号',
                hintText: '18 位,末位可为 X',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              validator: _validateIdCard,
            ),
            const SizedBox(height: 16),

            // 门店
            TextFormField(
              controller: _storeName,
              decoration: const InputDecoration(
                labelText: '门店名',
                hintText: '如:新华路XX地产',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => _required(v, '门店名'),
            ),
            const SizedBox(height: 16),

            // 手机号
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                labelText: '手机号',
                hintText: '11 位手机号',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),

            // 验证码
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      hintText: '6 位',
                      prefixIcon: Icon(Icons.sms_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateCode,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _countdown > 0 ? '${_countdown}s' : '获取验证码',
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('立即注册', style: TextStyle(fontSize: AppTheme.fontSectionTitle)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '已有账号?',
                  style: TextStyle(color: Colors.grey, fontSize: 12.0),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('去登录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}