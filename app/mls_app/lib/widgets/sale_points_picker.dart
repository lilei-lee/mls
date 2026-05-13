import 'package:flutter/material.dart';
import '../constants/sale_points_library.dart';

/// V2.2 #1: 卖点标签选择器共用组件(录入页 + 编辑页)
class SalePointsPicker extends StatefulWidget {
  final List<String> initialSelected;
  final ValueChanged<List<String>> onChanged;
  final int maxCustomCount;
  final int customMaxLength;

  const SalePointsPicker({
    super.key,
    required this.initialSelected,
    required this.onChanged,
    this.maxCustomCount = SalePointsLibrary.customMaxCount,
    this.customMaxLength = SalePointsLibrary.customMaxLength,
  });

  @override
  State<SalePointsPicker> createState() => _SalePointsPickerState();
}

class _SalePointsPickerState extends State<SalePointsPicker> {
  late List<String> _selectedPreset;
  late List<String> _customTags;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPreset = [];
    _customTags = [];
    for (final t in widget.initialSelected) {
      if (SalePointsLibrary.allPreset.contains(t)) {
        _selectedPreset.add(t);
      } else {
        _customTags.add(t);
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  int get _total => _selectedPreset.length + _customTags.length;

  void _emit() {
    widget.onChanged([..._selectedPreset, ..._customTags]);
  }

  void _togglePreset(String tag) {
    setState(() {
      if (_selectedPreset.contains(tag)) {
        _selectedPreset.remove(tag);
      } else {
        if (_total >= SalePointsLibrary.maxTotal) {
          _showToast('标签总数最多${SalePointsLibrary.maxTotal}个');
          return;
        }
        _selectedPreset.add(tag);
      }
    });
    _emit();
  }

  void _removeCustom(String tag) {
    setState(() => _customTags.remove(tag));
    _emit();
  }

  void _addCustom() {
    final raw = _customController.text.trim();
    if (raw.isEmpty) return;
    if (raw.length > widget.customMaxLength) {
      _showToast('自定义标签最多${widget.customMaxLength}字');
      return;
    }
    if (SalePointsLibrary.allPreset.contains(raw) || _customTags.contains(raw)) {
      _showToast('标签已存在');
      return;
    }
    if (_customTags.length >= widget.maxCustomCount) {
      _showToast('自定义标签最多${widget.maxCustomCount}个');
      return;
    }
    if (_total >= SalePointsLibrary.maxTotal) {
      _showToast('标签总数最多${SalePointsLibrary.maxTotal}个');
      return;
    }
    setState(() {
      _customTags.add(raw);
      _customController.clear();
    });
    _emit();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 已选标签
      if (_selectedPreset.isNotEmpty || _customTags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            ..._selectedPreset.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 11.0)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _togglePreset(t),
                  backgroundColor: Colors.red.shade50,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
            ..._customTags.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 11.0)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeCustom(t),
                  backgroundColor: Colors.deepOrange.shade50,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
          ]),
        ),

      // 预设标签分组
      ...SalePointsLibrary.presetGroups.entries.map((group) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.key, style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: group.value.map((tag) {
                final sel = _selectedPreset.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11.0)),
                  selected: sel,
                  onSelected: (_) => _togglePreset(tag),
                  selectedColor: Colors.blue.shade50,
                  checkmarkColor: Colors.blue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList()),
            ]),
          )),

      // 自定义标签输入
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _customController,
              decoration: const InputDecoration(
                hintText: '自定义标签(≤12字)',
                border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12.0),
              maxLength: widget.customMaxLength,
              buildCounter: (_, {required currentLength, required maxLength, required bool isFocused}) => null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: (_total >= SalePointsLibrary.maxTotal || _customTags.length >= widget.maxCustomCount)
                ? null : _addCustom,
            child: const Text('添加', style: TextStyle(fontSize: 12.0)),
          ),
        ),
      ]),
      Text(
        '$_total/${SalePointsLibrary.maxTotal} 标签  |  自定义 ${_customTags.length}/${widget.maxCustomCount}',
        style: const TextStyle(fontSize: 11.0, color: Colors.grey),
      ),
    ]);
  }
}
