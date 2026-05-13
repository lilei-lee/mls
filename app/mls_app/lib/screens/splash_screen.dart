import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';


/// 启动闪屏 - 决定 App 打开后第一眼看到什么
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// 检查保险柜,决定跳到哪里
  Future<void> _checkLoginStatus() async {
    final accessToken = await _storage.read(key: 'access_token');
    final name = await _storage.read(key: 'name');

    // 最短展示时间 500ms,避免一闪而过
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (accessToken != null && accessToken.isNotEmpty && name != null) {
      // 有 token → 直接进工作台
      context.go('/home?name=${Uri.encodeComponent(name)}');
    } else {
      // 没 token → 显示登录页
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              '张家口 MLS',
              style: TextStyle(fontSize: AppTheme.fontAppBar, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '经纪人协作平台',
              style: TextStyle(fontSize: 12.0, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}