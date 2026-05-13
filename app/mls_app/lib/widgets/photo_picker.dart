import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 单张照片数据(传给父组件)
class PickedPhoto {
  final String dataUrl;
  final int width;
  final int height;
  final int sizeKb;

  const PickedPhoto({
    required this.dataUrl,
    required this.width,
    required this.height,
    required this.sizeKb,
  });

  Map<String, dynamic> toJson() => {
        'data': dataUrl,
        'width': width,
        'height': height,
        'size_kb': sizeKb,
      };

  factory PickedPhoto.fromJson(Map<String, dynamic> json) => PickedPhoto(
        dataUrl: json['data'] as String,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        sizeKb: (json['size_kb'] as num?)?.toInt() ?? 0,
      );
}

class PhotoPicker extends StatefulWidget {
  final List<PickedPhoto> initialPhotos;
  final int maxCount;
  final ValueChanged<List<PickedPhoto>> onChanged;
  final ValueChanged<String?> onCoverThumbnailChanged;

  const PhotoPicker({
    super.key,
    this.initialPhotos = const [],
    this.maxCount = 6,
    required this.onChanged,
    required this.onCoverThumbnailChanged,
  });

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  late List<PickedPhoto> _photos;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
    debugPrint('📸 PhotoPicker initState: ${_photos.length} 张照片');
  }

  /// 关键:每次 _photos 变化后,统一调用此方法
  /// - 把当前 _photos 的 **深拷贝** 传给父组件
  /// - 同时重新计算封面缩略图(第一张的 dataUrl,或空)
  void _emitChange() {
    // 深拷贝一份给父组件,避免引用混乱
    final snapshot = _photos
        .map((p) => PickedPhoto(
              dataUrl: p.dataUrl,
              width: p.width,
              height: p.height,
              sizeKb: p.sizeKb,
            ))
        .toList();
    debugPrint('📸 PhotoPicker _emitChange: 当前 ${snapshot.length} 张,通知父组件');
    widget.onChanged(snapshot);

    // 同步封面缩略图
    if (_photos.isEmpty) {
      debugPrint('📸 PhotoPicker cover → null(无照片)');
      widget.onCoverThumbnailChanged(null);
    } else {
      debugPrint('📸 PhotoPicker cover → 用第一张 dataUrl(长度 ${_photos.first.dataUrl.length})');
      widget.onCoverThumbnailChanged(_photos.first.dataUrl);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_photos.length >= widget.maxCount) {
      _snack('最多 ${widget.maxCount} 张');
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (file == null) return;

      setState(() => _processing = true);

      final Uint8List? compressedBig = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1280,
        minHeight: 1280,
        quality: 80,
      );
      if (compressedBig == null) {
        _snack('图片压缩失败');
        return;
      }

      final bigBase64 =
          'data:image/jpeg;base64,${base64Encode(compressedBig)}';
      final bigSizeKb = (compressedBig.lengthInBytes / 1024).round();

      final picked = PickedPhoto(
        dataUrl: bigBase64,
        width: 0,
        height: 0,
        sizeKb: bigSizeKb,
      );

      setState(() {
        _photos.add(picked);
        _processing = false;
      });
      debugPrint('📸 添加照片,现在共 ${_photos.length} 张');
      _emitChange();

      _snack('已添加,大小 ${bigSizeKb}KB');
    } catch (e) {
      _snack('选择失败:$e');
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片'),
        content: Text(
          index == 0 && _photos.length > 1
              ? '封面照片将自动换为下一张。确认删除?'
              : '确认删除这张照片?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    debugPrint('📸 删除第 ${index + 1} 张,删除前 ${_photos.length} 张');

    setState(() {
      _photos.removeAt(index);
    });

    debugPrint('📸 删除后 ${_photos.length} 张,准备通知父组件');
    _emitChange();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '房源照片',
              style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_photos.length}/${widget.maxCount})',
              style: const TextStyle(color: Colors.grey, fontSize: 11.0),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._photos.asMap().entries.map((e) {
              final i = e.key;
              final photo = e.value;
              return _photoCell(photo, i);
            }),
            if (_photos.length < widget.maxCount) _addCell(),
          ],
        ),
        if (_processing) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('正在处理...',
                  style: TextStyle(color: Colors.grey, fontSize: 11.0)),
            ],
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          '首张自动作为封面,长按可删除',
          style: TextStyle(color: Colors.grey, fontSize: 11.0),
        ),
      ],
    );
  }

  Widget _photoCell(PickedPhoto photo, int index) {
    Uint8List? bytes;
    try {
      final comma = photo.dataUrl.indexOf(',');
      bytes = base64Decode(photo.dataUrl.substring(comma + 1));
    } catch (_) {}

    return GestureDetector(
      onLongPress: () => _deletePhoto(index),
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: AppTheme.grey400),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Container(color: AppTheme.grey200),
            ),
          ),
          if (index == 0)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const Text(
                  '封面',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addCell() {
    return GestureDetector(
      onTap: _processing ? null : _showSourceDialog,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
              color: AppTheme.grey400, style: BorderStyle.solid),
          color: Colors.grey.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 28, color: AppTheme.grey500),
            const SizedBox(height: 4),
            Text(
              '添加照片',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.0),
            ),
          ],
        ),
      ),
    );
  }
}