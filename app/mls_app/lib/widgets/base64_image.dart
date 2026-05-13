import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';

/// 渲染 base64 dataUrl 的图片
/// 输入格式:'data:image/jpeg;base64,XXX...' 或纯 base64 字符串
class Base64Image extends StatelessWidget {
  final String? dataUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const Base64Image({
    super.key,
    required this.dataUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  Uint8List? _decode(String raw) {
    try {
      final comma = raw.indexOf(',');
      final b64 = comma >= 0 ? raw.substring(comma + 1) : raw;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (dataUrl == null || dataUrl!.isEmpty) {
      return _buildPlaceholder();
    }
    final bytes = _decode(dataUrl!);
    if (bytes == null) return _buildPlaceholder();

    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: MlsColors.borderLight,
          alignment: Alignment.center,
          child: Icon(
            Icons.home_outlined,
            color: MlsColors.textTertiary,
            size: (width != null && width! < 60) ? 20 : 32,
          ),
        );
  }
}