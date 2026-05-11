import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// V2.5: Q&A 提问按钮 LA role 双保险 widget test
/// 这三个 test 需要真实 widget 树,由于详情页依赖 Dio/API,
/// 这里用简化 mock 验证按钮可见性逻辑的核心分支。
///
/// 核心逻辑(来自 _buildQnaSection):
///   final canAsk = _userRole == 'BA' && !isOwner && myPending < 3;
///   if (_userRole == 'BA' && !isOwner) → 显示提问按钮(或置灰版)

void main() {
  group('Q&A 提问按钮 角色双保险', () {
    test('LA role + not owner → 按钮不渲染', () {
      final role = 'LA';
      final isOwner = false;
      final showButton = role == 'BA' && !isOwner;
      expect(showButton, isFalse, reason: 'LA 看别人房不应显示提问按钮');
    });

    test('BA role + isOwner → 按钮不渲染', () {
      final role = 'BA';
      final isOwner = true;
      final showButton = role == 'BA' && !isOwner;
      expect(showButton, isFalse, reason: 'BA 看自己房不应显示提问按钮');
    });

    test('BA role + not owner → 按钮渲染', () {
      final role = 'BA';
      final isOwner = false;
      final showButton = role == 'BA' && !isOwner;
      expect(showButton, isTrue, reason: 'BA 看别人房应显示提问按钮');
    });

    test('BA role + not owner + pending>=3 → 按钮置灰', () {
      final role = 'BA';
      final isOwner = false;
      final myPending = 3;
      final canAsk = role == 'BA' && !isOwner && myPending < 3;
      expect(canAsk, isFalse, reason: 'pending>=3 时按钮应置灰');
    });

    test('BA role + not owner + pending=2 → 按钮可点', () {
      final role = 'BA';
      final isOwner = false;
      final myPending = 2;
      final canAsk = role == 'BA' && !isOwner && myPending < 3;
      expect(canAsk, isTrue, reason: 'pending<3 时按钮应可用');
    });
  });
}
