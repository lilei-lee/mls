/// 房源 / 协作 交易状态徽标 — 统一颜色映射
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 13});

  static const _listingColors = {
    'on_sale': Colors.green,
    'deposit_paid': Colors.blue,
    'transaction_ongoing': Colors.orange,
    'sold': Colors.grey,
    'paused': Colors.orange,
    'offline': Colors.grey,
  };

  static const _label = {
    'on_sale': '在售',
    'deposit_paid': '定金已付',
    'transaction_ongoing': '成交进行中',
    'sold': '已成交',
    'paused': '暂停',
    'offline': '已下架',
  };

  @override
  Widget build(BuildContext context) {
    final label = _label[status] ?? status;
    final color = _listingColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold)),
    );
  }
}
