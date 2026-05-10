import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/listing_filters.dart';
import '../services/meta_service.dart';
import '../constants/sale_points_library.dart';

/// V2.2: 5 类新筛选(卖点/格局/装修/供暖/楼龄) + V2.1 原有 4 类
class FilterSheet extends StatefulWidget {
  final ListingFilters initial;
  const FilterSheet({super.key, required this.initial});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  // V2.1
  late Set<String> _districts;
  late Set<int> _roomCounts;
  late RangeValues _areaRange;
  late RangeValues _priceRange;

  List<String> _districtOptions = [];
  bool _loadingDistricts = true;
  final List<int> _roomOptions = [1, 2, 3, 4];

  // V2.2
  late Set<String> _salePoints;
  late Set<String> _objectiveFeatures;
  String? _decoration;
  String? _heatingType;
  String? _orientation;
  String? _houseStructure;
  RangeValues _bldYearRange = const RangeValues(1990, 2026);

  static const _heatingOptions = ['集体供暖', '自供暖'];
  static const _orientationOptions = ['朝东', '朝西', '朝南', '朝北'];

  @override
  void initState() {
    super.initState();
    _districts = Set.from(widget.initial.districts);
    _roomCounts = Set.from(widget.initial.roomCounts);
    _areaRange = RangeValues(widget.initial.minArea, widget.initial.maxArea);
    _priceRange = RangeValues(widget.initial.minPrice, widget.initial.maxPrice);

    // V2.2
    _salePoints = Set.from(widget.initial.salePoints);
    _objectiveFeatures = Set.from(widget.initial.objectiveFeatures);
    _decoration = widget.initial.decoration;
    _heatingType = widget.initial.heatingType;
    _orientation = widget.initial.orientation;
    _houseStructure = widget.initial.houseStructure;
    _bldYearRange = RangeValues(
      (widget.initial.bldYearMin ?? 1990).toDouble(),
      (widget.initial.bldYearMax ?? 2026).toDouble(),
    );

    _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    try {
      final list = await MetaService.instance.getDistricts();
      if (mounted) setState(() { _districtOptions = list; _loadingDistricts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  void _resetAll() {
    setState(() {
      _districts = {};
      _roomCounts = {};
      _areaRange = const RangeValues(30, 200);
      _priceRange = const RangeValues(0, 500);
      _salePoints = {};
      _objectiveFeatures = {};
      _decoration = null;
      _heatingType = null;
      _orientation = null;
      _houseStructure = null;
      _bldYearRange = const RangeValues(1990, 2026);
    });
  }

  void _apply() {
    Navigator.of(context).pop(ListingFilters(
      districts: _districts,
      roomCounts: _roomCounts,
      minArea: _areaRange.start,
      maxArea: _areaRange.end,
      minPrice: _priceRange.start,
      maxPrice: _priceRange.end,
      salePoints: _salePoints,
      objectiveFeatures: _objectiveFeatures,
      decoration: _decoration,
      heatingType: _heatingType,
      bldYearMin: _bldYearRange.start.toInt() == 1990 ? null : _bldYearRange.start.toInt(),
      bldYearMax: _bldYearRange.end.toInt() == 2026 ? null : _bldYearRange.end.toInt(),
      orientation: _orientation,
      houseStructure: _houseStructure,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 8), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(children: [
                const Text('筛选条件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── V2.1 原有 ───
                  _sectionTitle('行政区'),
                  const SizedBox(height: 8),
                  _loadingDistricts
                      ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      : Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _districtOptions.map((d) {
                            final sel = _districts.contains(d);
                            return FilterChip(label: Text(d), selected: sel, onSelected: (v) {
                              setState(() { if (v) { _districts.add(d); } else { _districts.remove(d); } });
                            });
                          }).toList(),
                        ),
                  const SizedBox(height: 24),
                  _sectionTitle('户型'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _roomOptions.map((n) {
                      final sel = _roomCounts.contains(n);
                      return FilterChip(label: Text(n == 4 ? '4室+' : '$n室'), selected: sel, onSelected: (v) {
                        setState(() { if (v) { _roomCounts.add(n); } else { _roomCounts.remove(n); } });
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('朝向(单选)'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    ChoiceChip(
                      label: const Text('不限', style: TextStyle(fontSize: 12)),
                      selected: _orientation == null,
                      onSelected: (_) => setState(() => _orientation = null),
                    ),
                    ..._orientationOptions.map((o) => ChoiceChip(
                      label: Text(o, style: const TextStyle(fontSize: 12)),
                      selected: _orientation == o,
                      onSelected: (_) => setState(() => _orientation = _orientation == o ? null : o),
                    )),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle('面积'),
                  const SizedBox(height: 4),
                  Text('${_areaRange.start.toInt()}㎡ ~ ${_areaRange.end.toInt()}㎡', style: const TextStyle(color: Colors.blue, fontSize: 13)),
                  RangeSlider(min: 30, max: 200, divisions: 34, values: _areaRange,
                    labels: RangeLabels('${_areaRange.start.toInt()}㎡', '${_areaRange.end.toInt()}㎡'),
                    onChanged: (v) => setState(() => _areaRange = v),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('总价'),
                  const SizedBox(height: 4),
                  Text('${_priceRange.start.toInt()}万 ~ ${_priceRange.end.toInt()}万', style: const TextStyle(color: Colors.red, fontSize: 13)),
                  RangeSlider(min: 0, max: 500, divisions: 50, values: _priceRange,
                    labels: RangeLabels('${_priceRange.start.toInt()}万', '${_priceRange.end.toInt()}万'),
                    onChanged: (v) => setState(() => _priceRange = v),
                  ),
                  const SizedBox(height: 24),

                  // ═══ V2.2 卖点(多选) ═══
                  _sectionTitle('卖点标签(AND)'),
                  const SizedBox(height: 8),
                  ...SalePointsLibrary.presetGroups.entries.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.key, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4,
                        children: g.value.map((t) {
                          final sel = _salePoints.contains(t);
                          return FilterChip(
                            label: Text(t, style: const TextStyle(fontSize: 12)),
                            selected: sel,
                            onSelected: (v) {
                              setState(() { if (v) { _salePoints.add(t); } else { _salePoints.remove(t); } });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 16),

                  // ═══ V2.2 格局特点(多选) ═══
                  _sectionTitle('格局特点(AND)'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4,
                    children: SalePointsLibrary.objectiveFeatures.map((f) {
                      final sel = _objectiveFeatures.contains(f);
                      return FilterChip(
                        label: Text(f, style: const TextStyle(fontSize: 12)),
                        selected: sel, onSelected: (v) {
                          setState(() { if (v) { _objectiveFeatures.add(f); } else { _objectiveFeatures.remove(f); } });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ═══ V2.2 装修(单选) ═══
                  _sectionTitle('装修(单选)'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    ChoiceChip(
                      label: const Text('不限', style: TextStyle(fontSize: 12)),
                      selected: _decoration == null,
                      onSelected: (_) => setState(() => _decoration = null),
                    ),
                    ...SalePointsLibrary.decorationOptions.map((d) => ChoiceChip(
                      label: Text(d, style: const TextStyle(fontSize: 12)),
                      selected: _decoration == d,
                      onSelected: (_) => setState(() => _decoration = _decoration == d ? null : d),
                    )),
                  ]),
                  const SizedBox(height: 24),

                  // ═══ V2.2 供暖(单选) ═══
                  _sectionTitle('供暖(单选)'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    ChoiceChip(
                      label: const Text('不限', style: TextStyle(fontSize: 12)),
                      selected: _heatingType == null,
                      onSelected: (_) => setState(() => _heatingType = null),
                    ),
                    ..._heatingOptions.map((h) => ChoiceChip(
                      label: Text(h, style: const TextStyle(fontSize: 12)),
                      selected: _heatingType == h,
                      onSelected: (_) => setState(() => _heatingType = _heatingType == h ? null : h),
                    )),
                  ]),
                  const SizedBox(height: 24),

                  // ═══ V2.2 #2: 户型结构(单选) ═══
                  _sectionTitle('户型结构(单选)'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    ChoiceChip(
                      label: const Text('不限', style: TextStyle(fontSize: 12)),
                      selected: _houseStructure == null,
                      onSelected: (_) => setState(() => _houseStructure = null),
                    ),
                    ...SalePointsLibrary.houseStructureOptions.map((h) => ChoiceChip(
                      label: Text(h, style: const TextStyle(fontSize: 12)),
                      selected: _houseStructure == h,
                      onSelected: (_) => setState(() => _houseStructure = _houseStructure == h ? null : h),
                    )),
                  ]),
                  const SizedBox(height: 24),

                  // ═══ V2.2 楼龄(范围) ═══
                  _sectionTitle('楼龄(建成年代)'),
                  const SizedBox(height: 4),
                  Text('${_bldYearRange.start.toInt()}年 ~ ${_bldYearRange.end.toInt()}年',
                      style: const TextStyle(color: Colors.blue, fontSize: 13)),
                  RangeSlider(min: 1990, max: 2026, divisions: 36, values: _bldYearRange,
                    labels: RangeLabels('${_bldYearRange.start.toInt()}年', '${_bldYearRange.end.toInt()}年'),
                    onChanged: (v) => setState(() => _bldYearRange = v),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: _resetAll,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('重置'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('应用筛选', style: TextStyle(fontSize: 15)),
                  )),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
}
