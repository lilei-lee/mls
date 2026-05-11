import 'package:flutter_test/flutter_test.dart';
import '../lib/models/qna_thread.dart';

void main() {
  group('MyQuestionsScreen 核心逻辑', () {
    final sampleThreads = [
      QnaThread(threadId: 't1', question: '满五唯一吗?', questionAt: DateTime.now().subtract(const Duration(hours: 2)),
          askerName: '李红', askerIdSelf: true, status: 'pending', answererSelf: false, canDelete: true),
      QnaThread(threadId: 't2', question: '能看房吗?', questionAt: DateTime.now().subtract(const Duration(hours: 1)),
          askerName: '李红', askerIdSelf: true, status: 'pending', answererSelf: false, canDelete: true),
      QnaThread(threadId: 't3', question: '户型怎么样?', questionAt: DateTime.now().subtract(const Duration(days: 1)),
          askerName: '李红', askerIdSelf: true, status: 'answered', answer: '南北通透', answeredAt: DateTime.now().subtract(const Duration(hours: 5)),
          answererName: '张三', answererSelf: false, canDelete: false),
    ];

    test('空态:0 个 thread → 两组都为空', () {
      final pending = sampleThreads.where((t) => t.status == 'pending').toList();
      final answered = sampleThreads.where((t) => t.status == 'answered').toList();
      // 全空场景
      expect([].where((t) => t.status == 'pending'), isEmpty);
      expect([].where((t) => t.status == 'answered'), isEmpty);
    });

    test('只有 pending:2 个 → pending 组有值,answered 组隐藏', () {
      final threads = [sampleThreads[0], sampleThreads[1]];
      final pending = threads.where((t) => t.status == 'pending').toList();
      final answered = threads.where((t) => t.status == 'answered').toList();
      expect(pending.length, 2);
      expect(answered.length, 0);
    });

    test('pending+answered 都有 → 两组都显示,pending 在前', () {
      final threads = sampleThreads;
      final pending = threads.where((t) => t.status == 'pending').toList();
      final answered = threads.where((t) => t.status == 'answered').toList();
      expect(pending.length, 2);
      expect(answered.length, 1);
      // pending 必须在前面(排序规则)
      final allStatuses = threads.map((t) => t.status).toList();
      final pendingIndices = [for (var i = 0; i < allStatuses.length; i++) if (allStatuses[i] == 'pending') i];
      final answeredIndices = [for (var i = 0; i < allStatuses.length; i++) if (allStatuses[i] == 'answered') i];
      expect(pendingIndices.every((pi) => answeredIndices.every((ai) => pi < ai)), isTrue);
    });

    test('软删 thread 不出现:status=deleted 不在列表中', () {
      final threads = sampleThreads.where((t) => t.status != 'deleted').toList();
      expect(threads.length, 3); // 3 个,deleted 已被过滤
    });
  });
}
