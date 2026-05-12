import 'package:flutter/material.dart';
import 'theme/mls_theme.dart';
import 'screens/mls_preview_screen.dart';

/// MLS 组件预览独立入口 V1
///
/// 跑法 (在 app/mls_app/ 下):
///   flutter run --target=lib/main_preview.dart
///
/// 不影响 main.dart 主 App, 也不需要修改主路由。
/// 只挂载 MlsTheme.light + MlsPreviewScreen。
///
/// 用完关掉预览, 切回正常入口:
///   flutter run    (默认 target = lib/main.dart)
void main() => runApp(const MlsPreviewApp());

class MlsPreviewApp extends StatelessWidget {
  const MlsPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MLS 组件预览',
      theme: MlsTheme.light,
      home: const MlsPreviewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
