import 'package:flutter/material.dart';
import '../theme/mls_colors.dart';

/// 客户状态/等级 → 中文标签 + 颜色(列表卡片、详情共用)

const Map<String, String> customerStatusLabels = {
  'new': '新客',
  'following': '跟进中',
  'viewed': '已带看',
  'deal': '已成交',
  'lost': '已战败',
  // 兼容旧值(未迁移数据)
  'active': '跟进中',
  'closed': '已战败',
};

String customerStatusLabel(String? s) =>
    customerStatusLabels[s] ?? (s ?? '新客');

Color customerStatusColor(String? s) {
  switch (s) {
    case 'deal':
      return MlsColors.success;
    case 'lost':
    case 'closed':
      return MlsColors.textTertiary;
    case 'viewed':
      return MlsColors.primary;
    case 'following':
    case 'active':
      return MlsColors.warning;
    default: // new
      return MlsColors.primary;
  }
}

/// 意向等级 A/B/C → 颜色
Color customerGradeColor(String? g) {
  switch (g) {
    case 'A':
      return MlsColors.danger;
    case 'B':
      return MlsColors.warning;
    default: // C / null
      return MlsColors.textTertiary;
  }
}

const Map<String, String> genderLabels = {'male': '先生', 'female': '女士'};
String genderLabel(String? g) => genderLabels[g] ?? '';
