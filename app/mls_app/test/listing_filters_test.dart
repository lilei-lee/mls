import 'package:flutter_test/flutter_test.dart';
import 'package:mls_app/models/listing_filters.dart';

void main() {
  group('ListingFilters', () {
    group('isActive / isEmpty', () {
      test('empty 时 isActive 为 false', () {
        const f = ListingFilters.empty;
        expect(f.isActive, false);
        expect(f.isEmpty, true);
      });

      test('设了 minArea 后 isActive 为 true', () {
        const f = ListingFilters(minArea: 50);
        expect(f.isActive, true);
        expect(f.isEmpty, false);
      });

      test('设了 district 后 isActive 为 true', () {
        const f = ListingFilters(districts: {'桥东'});
        expect(f.isActive, true);
      });

      test('设了 salePoints 后 isActive 为 true', () {
        const f = ListingFilters(salePoints: {'满五唯一'});
        expect(f.isActive, true);
      });

      test('activeDimensionCount 正确计数', () {
        const f = ListingFilters(
          districts: {'桥东'},
          roomCounts: {2, 3},
        );
        expect(f.activeDimensionCount, 2);
      });

      test('全部默认值时 isEmpty 为 true', () {
        const f = ListingFilters();
        expect(f.isEmpty, true);
        expect(f.isActive, false);
      });
    });

    group('matches()', () {
      /// 标准房源 item（符合全部默认筛选条件）
      Map<String, dynamic> _baseItem() => {
            'district': '桥东',
            'rooms': 3,
            'area_sqm': 108.0,
            'price_wan': 150.0,
          };

      test('空筛选器 → 全部匹配', () {
        const f = ListingFilters.empty;
        expect(f.matches(_baseItem()), true);
      });

      test('area_sqm 为 null → 转为 0 → 小于 minArea(默认30) → 不匹配(坑49)', () {
        // 坑49: null 的 area_sqm 被当作 0，低于默认 minArea=30，被排除
        const f = ListingFilters.empty; // minArea=30 (default)
        final item = _baseItem()..remove('area_sqm');
        expect(f.matches(item), false);
      });

      test('area_sqm 为 null + minArea 设为 0 → 匹配', () {
        const f = ListingFilters(minArea: 0);
        final item = _baseItem()..remove('area_sqm');
        expect(f.matches(item), true);
      });

      test('价格区间过滤', () {
        const f = ListingFilters(minPrice: 80, maxPrice: 200);
        expect(f.matches({..._baseItem(), 'price_wan': 150}), true);
        expect(f.matches({..._baseItem(), 'price_wan': 60}), false);
        expect(f.matches({..._baseItem(), 'price_wan': 250}), false);
      });

      test('户型 bucket 过滤 (>=4 归入 4)', () {
        const f = ListingFilters(roomCounts: {2, 3});
        expect(f.matches({..._baseItem(), 'rooms': 2}), true);
        expect(f.matches({..._baseItem(), 'rooms': 1}), false);
        // 5 室 → bucket=4，不在 {2,3} 中
        expect(f.matches({..._baseItem(), 'rooms': 5}), false);
      });

      test('户型 >=4 归入 bucket 4', () {
        const f = ListingFilters(roomCounts: {4});
        expect(f.matches({..._baseItem(), 'rooms': 4}), true);
        expect(f.matches({..._baseItem(), 'rooms': 5}), true);
      });

      test('多条件 AND 逻辑: district + rooms + area + price 全部满足才匹配', () {
        const f = ListingFilters(
          districts: {'桥东'},
          roomCounts: {3},
          minArea: 50,
          maxArea: 200,
          minPrice: 100,
          maxPrice: 300,
        );
        // 全部满足
        expect(f.matches(_baseItem()), true);
        // district 不满足
        expect(
          f.matches({..._baseItem(), 'district': '经开区'}),
          false,
        );
        // rooms 不满足
        expect(f.matches({..._baseItem(), 'rooms': 2}), false);
        // area 不满足
        expect(f.matches({..._baseItem(), 'area_sqm': 30}), false);
        // price 不满足
        expect(f.matches({..._baseItem(), 'price_wan': 50}), false);
      });
    });

    group('toQueryParams', () {
      test('空筛选器 → 空参数', () {
        const f = ListingFilters.empty;
        expect(f.toQueryParams().isEmpty, true);
      });

      test('有 salePoints 时包含在 query 中', () {
        const f = ListingFilters(salePoints: {'满五唯一', '南北通透'});
        expect(f.toQueryParams()['sale_points'], '满五唯一,南北通透');
      });

      test('有 decoration 时包含在 query 中', () {
        const f = ListingFilters(decoration: '精装');
        expect(f.toQueryParams()['decoration'], '精装');
      });

      test('sort=default 时不包含在 query 中', () {
        const f = ListingFilters(sort: 'default');
        expect(f.toQueryParams().containsKey('sort'), false);
      });

      test('sort 非 default 时包含在 query 中', () {
        const f = ListingFilters(sort: 'price_desc');
        expect(f.toQueryParams()['sort'], 'price_desc');
      });
    });
  });
}
