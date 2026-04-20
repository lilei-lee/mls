import 'package:flutter/material.dart';
import '../models/listing_filters.dart';
import '../services/meta_service.dart';

/// 筛选抽屉 - 底部弹出
/// 用法:
///   final result = await showModalBottomSheet<ListingFilters>(
///     context: context,
///     isScrollControlled: true,
///     builder: (_) => FilterSheet(initial: currentFilters),
///   );
class FilterSheet extends StatefulWidget {
  final ListingFilters initial;
  const FilterSheet({super.key, required this.initial});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Set<String> _districts;
  late Set<int> _roomCounts;
  late RangeValues _areaRange;
  late RangeValues _priceRange;

  List<String> _districtOptions = [];
  bool _loadingDistricts = true;

  // 户型选项:1/2/3/4,显示为 1室/2室/3室/4室+
  final List<int> _roomOptions = [1, 2, 3, 4];

  @override
  void initState() {
    super.initState();
    _districts = Set.from(widget.initial.districts);
    _roomCounts = Set.from(widget.initial.roomCounts);
    _areaRange = RangeValues(widget.initial.minArea, widget.initial.maxArea);
    _priceRange = RangeValues(widget.initial.minPrice, widget.initial.maxPrice);
    _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    try {
      final list = await MetaService.instance.getDistricts();
      if (mounted) {
        setState(() {
          _districtOptions = list;
          _loadingDistricts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  void _reset() {
    setState(() {
      _districts = {};
      _roomCounts = {};
      _areaRange = const RangeValues(30, 200);
      _priceRange = const RangeValues(0, 500);
    });
  }

  void _apply() {
    final result = ListingFilters(
      districts: _districts,
      roomCounts: _roomCounts,
      minArea: _areaRange.start,
      maxArea: _areaRange.end,
      minPrice: _priceRange.start,
      maxPrice: _priceRange.end,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    // 用 DraggableScrollableSheet 做抽屉,支持向上拖到更大
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖拽提示条
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      '筛选条件',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 可滚动内容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('行政区'),
                    const SizedBox(height: 8),
                    _loadingDistricts
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _districtOptions.map((d) {
                              final selected = _districts.contains(d);
                              return FilterChip(
                                label: Text(d),
                                selected: selected,
                                onSelected: (v) {
                                  setState(() {
                                    if (v) {
                                      _districts.add(d);
                                    } else {
                                      _districts.remove(d);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 24),
                    _sectionTitle('户型'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roomOptions.map((n) {
                        final selected = _roomCounts.contains(n);
                        return FilterChip(
                          label: Text(n == 4 ? '4室+' : '$n室'),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _roomCounts.add(n);
                              } else {
                                _roomCounts.remove(n);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('面积'),
                    const SizedBox(height: 4),
                    Text(
                      '${_areaRange.start.toInt()}㎡ ~ ${_areaRange.end.toInt()}㎡',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                      ),
                    ),
                    RangeSlider(
                      min: 30,
                      max: 200,
                      divisions: 34, // 每格 5㎡
                      values: _areaRange,
                      labels: RangeLabels(
                        '${_areaRange.start.toInt()}㎡',
                        '${_areaRange.end.toInt()}㎡',
                      ),
                      onChanged: (v) => setState(() => _areaRange = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('总价'),
                    const SizedBox(height: 4),
                    Text(
                      '${_priceRange.start.toInt()}万 ~ ${_priceRange.end.toInt()}万',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                    RangeSlider(
                      min: 0,
                      max: 500,
                      divisions: 50, // 每格 10 万
                      values: _priceRange,
                      labels: RangeLabels(
                        '${_priceRange.start.toInt()}万',
                        '${_priceRange.end.toInt()}万',
                      ),
                      onChanged: (v) => setState(() => _priceRange = v),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // 底部按钮
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reset,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('重置'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _apply,
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            '应用筛选',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}