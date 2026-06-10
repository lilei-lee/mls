import 'package:flutter_test/flutter_test.dart';
import 'package:mls_app/utils/price_validation.dart';

void main() {
  group('priceWarning', () {
    test('null → null（未输入不拦截）', () {
      expect(priceWarning(null), null);
    });

    test('0 → null', () {
      expect(priceWarning(0), null);
    });

    test('5000 → "金额过低" 警告', () {
      final result = priceWarning(5000);
      expect(result, isNotNull);
      expect(result, contains('金额过低'));
    });

    test('10000 → null（刚好过万，合理）', () {
      expect(priceWarning(10000), null);
    });

    test('850000 → null（85 万，正常范围）', () {
      expect(priceWarning(850000), null);
    });

    test('5000000 → null（500 万，正常范围）', () {
      expect(priceWarning(5000000), null);
    });

    test('6 亿 → "超出合理范围"', () {
      final result = priceWarning(600000000);
      expect(result, isNotNull);
      expect(result, '金额超出合理范围');
    });

    test('5 亿整 → null（未超过阈值）', () {
      // 阈值是 > 500_000_000，等于不算超出
      expect(priceWarning(500000000), null);
    });

    test('负数 → null（不做校验）', () {
      expect(priceWarning(-100), null);
    });
  });
}
