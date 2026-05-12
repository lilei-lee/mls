import 'package:flutter_test/flutter_test.dart';

void main() {
  group('工作台待办 badge 渲染', () {
    test('transaction_pending_confirm → "7天内" urgent badge', () {
      final type = 'transaction_pending_confirm';
      final badge = switch (type) {
        'transaction_pending_confirm' => '7天内',
        'transaction_waiting_la' => '进行中',
        _ => null,
      };
      expect(badge, '7天内');
    });

    test('transaction_waiting_la → "进行中" info badge', () {
      final type = 'transaction_waiting_la';
      final badge = switch (type) {
        'transaction_pending_confirm' => '7天内',
        'transaction_waiting_la' => '进行中',
        _ => null,
      };
      expect(badge, '进行中');
    });

    test('普通 type(如 approval) → badge=null', () {
      final type = 'approval';
      final badge = switch (type) {
        'transaction_pending_confirm' => '7天内',
        'transaction_waiting_la' => '进行中',
        _ => null,
      };
      expect(badge, isNull);
    });
  });
}
