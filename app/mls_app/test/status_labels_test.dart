import 'package:flutter_test/flutter_test.dart';
import 'package:mls_app/widgets/status_labels.dart';

void main() {
  group('StatusLabels', () {
    group('general of()', () {
      test('null → "-"', () {
        expect(StatusLabels.of(null), '-');
      });

      test('空字符串 → "-"', () {
        expect(StatusLabels.of(''), '-');
      });

      test('已知 code → 正确中文', () {
        expect(StatusLabels.of('on_sale'), '在售');
        expect(StatusLabels.of('sold'), '已成交');
        expect(StatusLabels.of('approved'), '已通过');
        expect(StatusLabels.of('settled'), '已结清');
      });

      test('未知 code → 返回原样', () {
        expect(StatusLabels.of('unknown_status'), 'unknown_status');
      });
    });

    group('listing', () {
      test('null → "-"', () {
        expect(StatusLabels.listing(null), '-');
      });

      test('on_sale → "在售"', () {
        expect(StatusLabels.listing('on_sale'), '在售');
      });

      test('sold → "已成交"', () {
        expect(StatusLabels.listing('sold'), '已成交');
      });

      test('未知 → 返回原样', () {
        expect(StatusLabels.listing('foo'), 'foo');
      });
    });

    group('showingRequest', () {
      test('pending → "待审批"', () {
        expect(StatusLabels.showingRequest('pending'), '待审批');
      });

      test('auto_approved → "已通过(熟人直接带看)"', () {
        expect(
          StatusLabels.showingRequest('auto_approved'),
          '已通过(熟人直接带看)',
        );
      });
    });

    group('showing — Day 16 修订坑', () {
      test('pending_confirm → "待 LA 确认" (非 pending_la_confirm)', () {
        // Day 16 修订: showing 域用 pending_confirm，不是 pending_la_confirm
        expect(StatusLabels.showing('pending_confirm'), '待 LA 确认');
      });

      test('confirmed → "已确认"', () {
        expect(StatusLabels.showing('confirmed'), '已确认');
      });
    });

    group('transaction', () {
      test('pending_la_confirm → "待 LA 独立填价"', () {
        expect(
          StatusLabels.transaction('pending_la_confirm'),
          '待 LA 独立填价',
        );
      });
    });

    group('settlement', () {
      test('pending_payment → "待 LA 付款"', () {
        expect(StatusLabels.settlement('pending_payment'), '待 LA 付款');
      });

      test('settled → "已结清"', () {
        expect(StatusLabels.settlement('settled'), '已结清');
      });
    });
  });
}
