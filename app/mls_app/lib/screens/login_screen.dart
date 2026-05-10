import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import 'package:go_router/go_router.dart';

/// 登录页
/// Day 9 修:用 SingleChildScrollView 包裹,键盘弹出时内容可滚,不再 overflow
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  static const _storage = FlutterSecureStorage();

  bool _smsSent = false;
  bool _sendingSms = false;
  bool _loggingIn = false;

  String _phoneWhenSmsSent = '';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    if (_smsSent && _phoneController.text.trim() != _phoneWhenSmsSent) {
      setState(() {
        _smsSent = false;
        _codeController.clear();
      });
    }
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v.trim())) return '手机号格式不正确';
    return null;
  }

  String? _validateCode(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入验证码';
    return null;
  }

  Future<void> _sendSmsCode() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    setState(() => _sendingSms = true);

    try {
      final response = await ApiClient.instance.dio.post(
        '/auth/send-sms-code',
        data: {'phone': phone},
      );

      if (response.data['success'] == true) {
        _showMessage(response.data['message'] ?? '验证码已发送');
        setState(() {
          _smsSent = true;
          _phoneWhenSmsSent = phone;
        });
      } else {
        _showMessage('发送失败,请重试');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _showMessage('发送失败: $msg');
    } catch (e) {
      _showMessage('发送失败: $e');
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    setState(() => _loggingIn = true);

    try {
      final response = await ApiClient.instance.dio.post(
        '/auth/login',
        data: {'phone': phone, 'code': code},
      );

      final data = response.data;
      if (data['success'] == true) {
        await _storage.write(key: 'access_token', value: data['access_token']);
        await _storage.write(
            key: 'refresh_token', value: data['refresh_token']);
        await _storage.write(key: 'agent_id', value: data['agent_id']);
        await _storage.write(key: 'name', value: data['name']);

        _showMessage('登录成功!欢迎 ${data['name']}');

        if (mounted) {
          context.go('/home?name=${Uri.encodeComponent(data['name'])}');
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _showMessage('登录失败: $msg');
    } catch (e) {
      _showMessage('登录失败: $e');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MLS 登录')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                '张家口 MLS',
                style: TextStyle(fontSize: AppTheme.fontAppBar, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '经纪人协作平台',
                style: TextStyle(fontSize: AppTheme.fontBody, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              // 手机号 + 获取验证码
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      validator: _validatePhone,
                      decoration: const InputDecoration(
                        labelText: '手机号 *',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _sendingSms ? null : _sendSmsCode,
                      child: _sendingSms
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_smsSent ? '重新发送' : '获取验证码'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 验证码 + 登录按钮(只在发送后显示)
              if (_smsSent) ...[
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: _validateCode,
                  decoration: const InputDecoration(
                    labelText: '验证码 *',
                    hintText: '请输入6位验证码',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loggingIn ? null : _login,
                    child: _loggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('登 录', style: TextStyle(fontSize: AppTheme.fontSectionTitle)),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // 立即注册(不再尝试顶到底部,自然跟随内容后面)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '还没账号?',
                    style: TextStyle(color: Colors.grey, fontSize: AppTheme.fontBody),
                  ),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('立即注册'),
                  ),
                ],
              ),
            ],
          ),
        ),  // Column
      ),    // Form
      ),
    );
  }
}