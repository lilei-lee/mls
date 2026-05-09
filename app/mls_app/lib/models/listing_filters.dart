/// V2.2 #1: 筛选条件数据类 — 加 5 类新筛选
class ListingFilters {
  // V2.1 原有
  final Set<String> districts;
  final Set<int> roomCounts;
  final double minArea;
  final double maxArea;
  final double minPrice;
  final double maxPrice;

  // V2.2 新增
  final Set<String> salePoints;
  final Set<String> objectiveFeatures;
  final String? decoration;
  final String? heatingType;
  final int? bldYearMin;
  final int? bldYearMax;

  const ListingFilters({
    this.districts = const {},
    this.roomCounts = const {},
    this.minArea = _defaultMinArea,
    this.maxArea = _defaultMaxArea,
    this.minPrice = _defaultMinPrice,
    this.maxPrice = _defaultMaxPrice,
    this.salePoints = const {},
    this.objectiveFeatures = const {},
    this.decoration,
    this.heatingType,
    this.bldYearMin,
    this.bldYearMax,
  });

  static const double _defaultMinArea = 30;
  static const double _defaultMaxArea = 200;
  static const double _defaultMinPrice = 0;
  static const double _defaultMaxPrice = 500;

  bool get isEmpty =>
      districts.isEmpty &&
      roomCounts.isEmpty &&
      minArea == _defaultMinArea &&
      maxArea == _defaultMaxArea &&
      minPrice == _defaultMinPrice &&
      maxPrice == _defaultMaxPrice &&
      salePoints.isEmpty &&
      objectiveFeatures.isEmpty &&
      decoration == null &&
      heatingType == null &&
      bldYearMin == null &&
      bldYearMax == null;

  bool get isActive => !isEmpty;

  int get activeDimensionCount {
    int count = 0;
    if (districts.isNotEmpty) count++;
    if (roomCounts.isNotEmpty) count++;
    if (minArea != _defaultMinArea || maxArea != _defaultMaxArea) count++;
    if (minPrice != _defaultMinPrice || maxPrice != _defaultMaxPrice) count++;
    if (salePoints.isNotEmpty) count++;
    if (objectiveFeatures.isNotEmpty) count++;
    if (decoration != null) count++;
    if (heatingType != null) count++;
    if (bldYearMin != null || bldYearMax != null) count++;
    return count;
  }

  static const ListingFilters empty = ListingFilters();

  /// 构建服务器端筛选查询参数(V2.2 新增)
  Map<String, String> toQueryParams() {
    final p = <String, String>{};
    if (salePoints.isNotEmpty) p['sale_points'] = salePoints.join(',');
    if (objectiveFeatures.isNotEmpty) p['objective_features'] = objectiveFeatures.join(',');
    if (decoration != null) p['decoration'] = decoration!;
    if (heatingType != null) p['heating_type'] = heatingType!;
    if (bldYearMin != null) p['bld_year_min'] = bldYearMin.toString();
    if (bldYearMax != null) p['bld_year_max'] = bldYearMax.toString();
    return p;
  }

  bool matches(Map<String, dynamic> item) {
    if (districts.isNotEmpty) {
      final d = (item['district'] ?? '').toString();
      if (!districts.contains(d)) return false;
    }
    if (roomCounts.isNotEmpty) {
      final r = (item['rooms'] as num?)?.toInt() ?? 0;
      final bucket = r >= 4 ? 4 : r;
      if (!roomCounts.contains(bucket)) return false;
    }
    final area = (item['area_sqm'] as num?)?.toDouble() ?? 0;
    if (area < minArea || area > maxArea) return false;
    final price = (item['price_wan'] as num?)?.toDouble() ?? 0;
    if (price < minPrice || price > maxPrice) return false;
    return true;
  }
}
