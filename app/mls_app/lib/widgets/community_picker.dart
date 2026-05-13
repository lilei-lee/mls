import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:dio/dio.dart';
import '../services/community_service.dart';

/// 选中的小区
class PickedCommunity {
  final String id;
  final String name;
  final String district;

  const PickedCommunity({
    required this.id,
    required this.name,
    required this.district,
  });
}

/// 小区选择器:点击弹出带搜索的选择页
///
/// 用法:
/// ```dart
/// CommunityPicker(
///   initial: _pickedCommunity,
///   districts: _districts, // 用于"添加新小区"时选行政区
///   onChanged: (picked) {
///     setState(() {
///       _pickedCommunity = picked;
///       _selectedDistrict = picked.district; // 自动回填
///     });
///   },
/// )
/// ```
class CommunityPicker extends StatelessWidget {
  final PickedCommunity? initial;
  final List<String> districts;
  final ValueChanged<PickedCommunity> onChanged;

  const CommunityPicker({
    super.key,
    required this.initial,
    required this.districts,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await Navigator.of(context).push<PickedCommunity>(
      MaterialPageRoute(
        builder: (_) => _CommunityPickerScreen(districts: districts),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final has = initial != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(4.0),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '小区名',
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.apartment_outlined),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            hintText: has ? null : '点击选择或添加',
          ),
          child: has
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        initial!.name,
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        initial!.district,
                        style: TextStyle(
                          fontSize: 11.0,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                )
              : const Text('点击选择或添加',
                  style: TextStyle(color: Colors.grey, fontSize: 12.0)),
        ),
      ),
    );
  }
}

// ==================== 选择页(全屏) ====================

class _CommunityPickerScreen extends StatefulWidget {
  final List<String> districts;
  const _CommunityPickerScreen({required this.districts});

  @override
  State<_CommunityPickerScreen> createState() => _CommunityPickerScreenState();
}

class _CommunityPickerScreenState extends State<_CommunityPickerScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _doSearch(q.trim());
    });
  }

  Future<void> _doSearch(String q) async {
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final items = await CommunityService.instance.search(query: q);
      if (!mounted) return;
      // 防抖竞态:只在是最后一次查询时才更新
      if (q != _lastQuery) return;
      setState(() {
        _results = items;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<PickedCommunity>(
      context: context,
      builder: (ctx) => _AddCommunityDialog(
        districts: widget.districts,
        prefillName: _searchController.text.trim(),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _pick(Map<String, dynamic> item) {
    Navigator.of(context).pop(PickedCommunity(
      id: item['community_id'] as String,
      name: item['name'] as String,
      district: item['district'] as String,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim();
    final hasQuery = q.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('选择小区')),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: '输入小区名关键字(如:碧桂园)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildBody(hasQuery)),
        ],
      ),
    );
  }

  Widget _buildBody(bool hasQuery) {
    if (!hasQuery) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 60, color: Colors.grey),
              SizedBox(height: 12),
              Text('搜索小区库',
                  style: TextStyle(color: Colors.grey, fontSize: 12.0)),
              SizedBox(height: 4),
              Text('输入名字关键词开始查找',
                  style: TextStyle(color: Colors.grey, fontSize: 11.0)),
            ],
          ),
        ),
      );
    }

    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    // 有查询、不在加载 → 显示结果或空态
    return ListView(
      children: [
        ..._results.map((it) => _buildResultTile(it)),
        const Divider(height: 1),
        // 固定底部:添加新小区
        ListTile(
          leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
          title: Text(
            _results.isEmpty
                ? '没找到?添加「${_searchController.text.trim()}」'
                : '没找到?添加新小区',
            style: const TextStyle(color: Colors.blue, fontSize: 12.0),
          ),
          onTap: _openAddDialog,
        ),
      ],
    );
  }

  Widget _buildResultTile(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final district = item['district'] as String;
    final builtYear = item['built_year'];
    return ListTile(
      leading: const Icon(Icons.apartment, color: Colors.blueGrey),
      title: Text(name, style: const TextStyle(fontSize: 16.0)),
      subtitle: Text(
        '$district${builtYear != null ? " · $builtYear年建" : ""}',
        style: const TextStyle(fontSize: 11.0),
      ),
      onTap: () => _pick(item),
    );
  }
}

// ==================== 新增小区对话框 ====================

class _AddCommunityDialog extends StatefulWidget {
  final List<String> districts;
  final String prefillName;
  const _AddCommunityDialog({
    required this.districts,
    required this.prefillName,
  });

  @override
  State<_AddCommunityDialog> createState() => _AddCommunityDialogState();
}

class _AddCommunityDialogState extends State<_AddCommunityDialog> {
  late final TextEditingController _nameController;
  String? _selectedDistrict;
  final _builtYearController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prefillName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _builtYearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('请填写小区名');
      return;
    }
    if (_selectedDistrict == null) {
      _snack('请选择行政区');
      return;
    }

    int? builtYear;
    final byText = _builtYearController.text.trim();
    if (byText.isNotEmpty) {
      builtYear = int.tryParse(byText);
      if (builtYear == null || builtYear < 1900 || builtYear > 2100) {
        _snack('建成年份格式不对');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final id = await CommunityService.instance.create(
        name: name,
        district: _selectedDistrict!,
        builtYear: builtYear,
      );
      if (!mounted) return;
      Navigator.of(context).pop(PickedCommunity(
        id: id,
        name: name,
        district: _selectedDistrict!,
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      // 409 说明已存在,直接复用已有小区
      if (e.response?.statusCode == 409) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['community_id'] != null) {
          Navigator.of(context).pop(PickedCommunity(
            id: detail['community_id'] as String,
            name: (detail['name'] ?? name) as String,
            district: (detail['district'] ?? _selectedDistrict) as String,
          ));
          return;
        }
        _snack(detail is Map ? (detail['message'] ?? '小区已存在') : '小区已存在');
      } else {
        final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
        _snack('添加失败:$msg');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加新小区'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: '小区名 *',
                hintText: '如:碧桂园天玺',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: const InputDecoration(
                labelText: '行政区 *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: widget.districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDistrict = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _builtYearController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '建成年代(选填)',
                hintText: '如:2015',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('添加', style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}