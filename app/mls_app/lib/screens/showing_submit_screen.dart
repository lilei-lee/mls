import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/showing_service.dart';

/// BA 提交带看记录(交易留痕节点 ④)
class ShowingSubmitScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> snapshot;

  const ShowingSubmitScreen({
    super.key,
    required this.requestId,
    required this.snapshot,
  });

  @override
  State<ShowingSubmitScreen> createState() => _ShowingSubmitScreenState();
}

class _ShowingSubmitScreenState extends State<ShowingSubmitScreen> {
  static const int _maxPhotos = 3;

  DateTime? _showingTime;
  final List<String> _photos = []; // base64 data URL
  final _notesController = TextEditingController();

  bool _submitting = false;
  bool _picking = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _showingTime ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_showingTime ?? now),
    );
    if (time == null) return;

    setState(() {
      _showingTime = DateTime(
        picked.year, picked.month, picked.day,
        time.hour, time.minute,
      );
    });
  }

  Future<void> _showSourceSheet() async {
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

  Future<void> _pickImage(ImageSource source) async {
    if (_photos.length >= _maxPhotos || _picking) return;

    setState(() => _picking = true);
    try {
      final xfile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 75,
      );
      final b64 = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      if (!mounted) return;
      setState(() => _photos.add(b64));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选取失败:$e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePhoto(int idx) {
    setState(() => _photos.removeAt(idx));
  }

  Future<void> _submit() async {
    if (_showingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择带看时间')),
      );
      return;
    }
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少拍摄 1 张现场照片')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ShowingService.instance.submit(
        showingRequestId: widget.requestId,
        showingTime: _showingTime!,
        photos: _photos,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('带看记录已提交,等待 LA 确认')),
      );
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('提交失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('提交带看记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('目标房源',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    '${sp['community']} ${sp['building']}号楼${sp['unit']}单元${sp['room_no']}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sp['layout'] ?? ''} · ${sp['area_sqm']}㎡ · ¥${sp['price_wan']}万',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('带看时间 *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    _showingTime == null ? '点击选择实际带看时间' : _formatTime(_showingTime!),
                    style: TextStyle(
                      color: _showingTime == null ? Colors.grey : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text('现场照片 *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Text('${_photos.length}/$_maxPhotos',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          _buildPhotoGrid(),
          const SizedBox(height: 20),

          const Text('带看备注(选填)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '例如:客户对客厅采光满意,对厨房面积有疑虑...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_submitting ? '提交中...' : '提交带看记录',
                  style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = (constraints.maxWidth - spacing * 2) / 3;
        final tiles = <Widget>[];
        for (int i = 0; i < _photos.length; i++) {
          tiles.add(_buildPhotoTile(i, w));
        }
        if (_photos.length < _maxPhotos) {
          tiles.add(_buildAddTile(w));
        }
        return Wrap(spacing: spacing, runSpacing: spacing, children: tiles);
      },
    );
  }

  Widget _buildPhotoTile(int idx, double size) {
    final b64 = _photos[idx];
    final commaIdx = b64.indexOf(',');
    final raw = commaIdx > 0 ? b64.substring(commaIdx + 1) : b64;
    final bytes = base64Decode(raw);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes,
              width: size, height: size, fit: BoxFit.cover),
        ),
        Positioned(
          top: -6, right: -6,
          child: GestureDetector(
            onTap: () => _removePhoto(idx),
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddTile(double size) {
    return InkWell(
      onTap: _picking ? null : _showSourceSheet,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _picking
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt, color: Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(_picking ? '处理中' : '拍照',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}