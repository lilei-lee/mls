import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_typography.dart';

/// 两宫格大切换 V1
///
/// 买/卖方等宽切换。选中时 accent 高亮。
///
/// 用法:
/// ```dart
/// MlsBigToggle(
///   left: (icon: Icons.search, label: '买方', sub: '找房需求'),
///   right: (icon: Icons.sell, label: '卖方', sub: '委托出售'),
///   leftAccent: MlsColors.primary,
///   rightAccent: MlsColors.gold,
///   isLeft: _side == 'buy',
///   onChanged: (left) => setState(() => _side = left ? 'buy' : 'sell'),
/// )
/// ```
class MlsBigToggle extends StatelessWidget {
  final ({IconData icon, String label, String? sub}) left;
  final ({IconData icon, String label, String? sub}) right;
  final Color leftAccent;
  final Color rightAccent;
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const MlsBigToggle({
    super.key,
    required this.left,
    required this.right,
    required this.leftAccent,
    required this.rightAccent,
    required this.isLeft,
    required this.onChanged,
  });

  Widget _buildSide({
    required IconData icon,
    required String label,
    required String? sub,
    required Color accent,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : MlsColors.bgCardPrimary,
            borderRadius: BorderRadius.all(Radius.circular(MlsRadius.xl)),
            border: Border.all(
              color: selected ? accent : MlsColors.borderStrong,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? accent : MlsColors.textTertiary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamilyFallback: MlsTypography.sansFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : MlsColors.textSecondary,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamilyFallback: MlsTypography.sansFallback,
                    fontSize: 11,
                    color: MlsColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildSide(
          icon: left.icon,
          label: left.label,
          sub: left.sub,
          accent: leftAccent,
          selected: isLeft,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 12),
        _buildSide(
          icon: right.icon,
          label: right.label,
          sub: right.sub,
          accent: rightAccent,
          selected: !isLeft,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}
