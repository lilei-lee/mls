import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/showing_service.dart';

/// Day 16:直接带看新建页(1:N 模式)
///
/// 入口:协作详情页 → 已确认带看记录区 → "再次带看"按钮
/// 客户和房源信息只读展示(从 prior_request 透传,不允许换),仅可填:
/// - 带看时间
/// - 现场照片 1-3 张
/// - 备注
class DirectShowingCreateScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> listingSnapshot;
  final String customerLabel; // "张先生" / "陈女士",仅展示

  const DirectShowingCreateScreen({
    super.key,
    required this.listingId,
    required this.listingSnapshot,
    required this.customerLabel,
  });

  @override
  State<DirectShowingCreateScreen> createState() =>
      _DirectShowingCreateScreenState();
}

class _DirectShowingCreateScreenState extends State<DirectShowingCreateScreen> {
  final _notes = TextEditingController();
  DateTime? _showingTime;
  final List<String> _photos = []; // base64
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _showingTime ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_showingTime ?? now),
    );
    if (time == null) return;

    setState(() {
      _showingTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
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
    if (_photos.length >= 3) {
      _snack('最多 3 张照片');
      return;
    }
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    setState(() => _photos.add(base64Encode(bytes)));
  }

  Future<void> _submit() async {
    if (_showingTime == null) {
      _snack('请选择带看时间');
      return;
    }
    if (_photos.isEmpty) {
      _snack('请至少上传一张现场照片');
      return;
    }

    setState(() => _submitting = true);
    try {
      final showingId = await ShowingService.instance.createDirect(
        listingId: widget.listingId,
        showingTime: _showingTime!,
        photos: _photos,
        notes: _notes.text.trim(),
      );

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              size: 60, color: Colors.green),
          title: const Text('带看记录已提交'),
          content: const Text(
            '已提交给 LA 确认。\n确认后该次带看会进入留痕链。',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) context.pop(true); // 返回上级
                },
                child: const Text('好的'),
              ),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('提交失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.listingSnapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('再次带看')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1:N 模式说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '基于已通过的申请,直接发起新一次带看记录,无需再走审批。',
                    style: TextStyle(fontSize: AppTheme.fontCaption),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 房源信息(只读)
          const Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Text('目标房源',
                style: TextStyle(color: Colors.grey, fontSize: AppTheme.fontCaption)),
          ),
          Card(
            color: Colors.grey.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s['community']} ${s['building']}号楼${s['unit']}单元${s['room_no']}',
                    style: const TextStyle(
                        fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s['layout'] ?? ''} · ${s['area_sqm']}㎡ · ¥${s['price_wan']}万',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: AppTheme.fontBody),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 客户信息(只读 · 1:N 不允许换客户)
          const Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Text('客户(沿用首次申请)',
                style: TextStyle(color: Colors.grey, fontSize: AppTheme.fontCaption)),
          ),
          Card(
            color: Colors.grey.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(widget.customerLabel,
                      style: const TextStyle(
                          fontSize: AppTheme.fontSectionTitle, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 带看时间
          const Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Text('带看时间',
                style: TextStyle(color: Colors.grey, fontSize: AppTheme.fontCaption)),
          ),
          InkWell(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.grey400),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _showingTime == null ? '请选择带看时间' : _fmtTime(_showingTime!),
                    style: TextStyle(
                      fontSize: AppTheme.fontSectionTitle,
                      color: _showingTime == null
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 现场照片
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text('现场照片(1-3 张) · 已 ${_photos.length} 张',
                style:
                    const TextStyle(color: Colors.grey, fontSize: AppTheme.fontCaption)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._photos.asMap().entries.map((e) {
                final idx = e.key;
                final b64 = e.value;
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(b64)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _photos.removeAt(idx)),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppTheme.colorError,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_photos.length < 3)
                GestureDetector(
                  onTap: _showSourceSheet,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.grey400,
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(Icons.add_a_photo,
                        color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 备注
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: '备注(可选)',
              hintText: '本次带看简要记录,如客户反馈、是否决定等',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

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
                  : const Text('提交带看记录',
                      style: TextStyle(fontSize: AppTheme.fontSectionTitle)),
            ),
          ),
        ],
      ),
    );
  }
}