import 'package:flutter/material.dart';

/// 信息卡片(标签 + 值),用于展示"字段 + 内容"样式的数据
class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const InfoCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }
}