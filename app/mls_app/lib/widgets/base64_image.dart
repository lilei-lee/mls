import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';

/// 渲染 base64 dataUrl 的图片
/// 输入格式:'data:image/jpeg;base64,XXX...' 或纯 base64 字符串
///
/// V2: 改为 StatefulWidget，initState 解码一次，didUpdateWidget
/// 仅当 dataUrl 变化时重新解码，避免列表滚动中重复 base64Decode。
class Base64Image extends StatefulWidget {
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

  @override
  State<Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<Base64Image> {
  Uint8List? _bytes;

  static Uint8List? _decode(String raw) {
    try {
      final comma = raw.indexOf(',');
      final b64 = comma >= 0 ? raw.substring(comma + 1) : raw;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.dataUrl != null && widget.dataUrl!.isNotEmpty) {
      _bytes = _decode(widget.dataUrl!);
    }
  }

  @override
  void didUpdateWidget(covariant Base64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataUrl != oldWidget.dataUrl) {
      if (widget.dataUrl != null && widget.dataUrl!.isNotEmpty) {
        _bytes = _decode(widget.dataUrl!);
      } else {
        _bytes = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) return _buildPlaceholder();

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: MlsColors.borderLight,
          alignment: Alignment.center,
          child: Icon(
            Icons.home_outlined,
            color: MlsColors.textTertiary,
            size: (widget.width != null && widget.width! < 60) ? 20 : 32,
          ),
        );
  }
}
