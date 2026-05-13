import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';

/// 房源 / 协作 状态徽标 — v2.0 统一 Pill 样式
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const AppStatusBadge({super.key, required this.label, required this.color, this.fontSize = 12});

  /// 从 listing status 构建
  factory AppStatusBadge.listing(String status) {
    final label = {
      'on_sale': '在售', 'deposit_paid': '定金已付', 'transaction_ongoing': '成交进行中',
      'sold': '已成交', 'paused': '暂停', 'offline': '已下架',
    }[status] ?? status;
    final color = AppTheme.listingStatusColor[status] ?? MlsColors.textSecondary;
    return AppStatusBadge(label: label, color: color);
  }

  /// 从协作 status 构建
  factory AppStatusBadge.collab(String status) {
    final label = {
      'pending': '待审核', 'approved': '已通过', 'showing_done': '已带看',
      'transaction_initiated': '已发起成交', 'transaction_confirmed': '已成交',
      'rejected': '已拒绝', 'canceled': '已取消',
    }[status] ?? status;
    final color = AppTheme.collabStatusColor[status] ?? MlsColors.textSecondary;
    return AppStatusBadge(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusS)),
      child: Text(label, style: AppTheme.caption.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
