import 'package:flutter_test/flutter_test.dart';
import 'package:mls_app/utils/time_format.dart';

/// 构造相对于 now 的 ISO 时间字符串
String _isoFromNow(Duration offset) =>
    DateTime.now().subtract(offset).toUtc().toIso8601String();

void main() {
  group('relativeTime', () {
    test('null → 空字符串', () {
      expect(relativeTime(null), '');
    });

    test('非法字符串 → 空字符串', () {
      expect(relativeTime('not-a-date'), '');
    });

    test('30 秒前 → 刚刚', () {
      expect(relativeTime(_isoFromNow(const Duration(seconds: 30))), '刚刚');
    });

    test('5 分钟前', () {
      expect(
        relativeTime(_isoFromNow(const Duration(minutes: 5))),
        '5 分钟前',
      );
    });

    test('3 小时前', () {
      expect(
        relativeTime(_isoFromNow(const Duration(hours: 3))),
        '3 小时前',
      );
    });

    test('2 天前', () {
      expect(
        relativeTime(_isoFromNow(const Duration(days: 2))),
        '2 天前',
      );
    });

    test('45 天前 → 1 个月前', () {
      expect(
        relativeTime(_isoFromNow(const Duration(days: 45))),
        '1 个月前',
      );
    });

    test('空字符串 → 空字符串', () {
      expect(relativeTime(''), '');
    });
  });
}
