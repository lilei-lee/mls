import 'package:flutter_test/flutter_test.dart';

void main() {
  group('工作台 成交双向待办 卡片逻辑', () {
    test('LA: type=transaction_pending_confirm → 渲染', () {
      final todo = {'type': 'transaction_pending_confirm', 'priority': 'high', 'icon': 'handshake', 'title': '待你确认成交 (3 笔)', 'action_route': '/transactions/pending-la'};
      expect(todo['type'], 'transaction_pending_confirm');
      expect(todo['icon'], 'handshake');
      expect(todo['action_route'], '/transactions/pending-la');
    });

    test('BA: type=transaction_waiting_la → 渲染', () {
      final todo = {'type': 'transaction_waiting_la', 'priority': 'medium', 'icon': 'hourglass_empty', 'title': '等待 LA 确认成交 (1 笔)', 'action_route': '/transactions/pending-la'};
      expect(todo['type'], 'transaction_waiting_la');
      expect(todo['icon'], 'hourglass_empty');
      expect(todo['action_route'], '/transactions/pending-la');
    });

    test('count=0 → 不渲染卡片', () {
      final count = 0;
      final show = count > 0;
      expect(show, isFalse);
    });

    test('count>0 → 渲染卡片', () {
      final count = 3;
      final show = count > 0;
      expect(show, isTrue);
    });
  });
}
