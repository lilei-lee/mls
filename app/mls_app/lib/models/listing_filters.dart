/// 筛选条件数据类
/// - 保存用户在筛选抽屉里选的所有条件
/// - 跨页面复用(列表页 / 共享库)
class ListingFilters {
  /// 选中的行政区(空集 = 不限)
  final Set<String> districts;

  /// 选中的户型(1/2/3/4,4 代表 4+)
  final Set<int> roomCounts;

  /// 面积范围(㎡)
  final double minArea;
  final double maxArea;

  /// 总价范围(万元)
  final double minPrice;
  final double maxPrice;

  const ListingFilters({
    this.districts = const {},
    this.roomCounts = const {},
    this.minArea = _defaultMinArea,
    this.maxArea = _defaultMaxArea,
    this.minPrice = _defaultMinPrice,
    this.maxPrice = _defaultMaxPrice,
  });

  // 滑块默认范围
  static const double _defaultMinArea = 30;
  static const double _defaultMaxArea = 200;
  static const double _defaultMinPrice = 0;
  static const double _defaultMaxPrice = 500;

  /// 判断是否"完全没筛选"(用于 UI 显示有没有 dot/角标)
  bool get isEmpty =>
      districts.isEmpty &&
      roomCounts.isEmpty &&
      minArea == _defaultMinArea &&
      maxArea == _defaultMaxArea &&
      minPrice == _defaultMinPrice &&
      maxPrice == _defaultMaxPrice;

  bool get isActive => !isEmpty;

  /// 统计当前启用了多少个维度(用于按钮徽标数字)
  int get activeDimensionCount {
    int count = 0;
    if (districts.isNotEmpty) count++;
    if (roomCounts.isNotEmpty) count++;
    if (minArea != _defaultMinArea || maxArea != _defaultMaxArea) count++;
    if (minPrice != _defaultMinPrice || maxPrice != _defaultMaxPrice) count++;
    return count;
  }

  /// 空筛选常量(重置用)
  static const ListingFilters empty = ListingFilters();

  /// copyWith:改一两个字段时方便
  ListingFilters copyWith({
    Set<String>? districts,
    Set<int>? roomCounts,
    double? minArea,
    double? maxArea,
    double? minPrice,
    double? maxPrice,
  }) {
    return ListingFilters(
      districts: districts ?? this.districts,
      roomCounts: roomCounts ?? this.roomCounts,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  /// 对单条房源做匹配判断
  bool matches(Map<String, dynamic> item) {
    // 1. 行政区(空集=不限)
    if (districts.isNotEmpty) {
      final d = (item['district'] ?? '').toString();
      if (!districts.contains(d)) return false;
    }

    // 2. 户型
    if (roomCounts.isNotEmpty) {
      final r = (item['rooms'] as num?)?.toInt() ?? 0;
      final bucket = r >= 4 ? 4 : r;
      if (!roomCounts.contains(bucket)) return false;
    }

    // 3. 面积
    final area = (item['area_sqm'] as num?)?.toDouble() ?? 0;
    if (area < minArea || area > maxArea) return false;

    // 4. 总价
    final price = (item['price_wan'] as num?)?.toDouble() ?? 0;
    if (price < minPrice || price > maxPrice) return false;

    return true;
  }
}