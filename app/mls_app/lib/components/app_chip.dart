import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppChip extends StatelessWidget {
  final String label;
  final _ChipVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  const AppChip._({required this.label, required this.variant, this.icon, this.onTap, this.onDeleted});

  const AppChip.default_(String label, {IconData? icon, VoidCallback? onTap, VoidCallback? onDeleted})
      : this._(label: label, variant: _ChipVariant.default_, icon: icon, onTap: onTap, onDeleted: onDeleted);

  const AppChip.selected(String label, {IconData? icon, VoidCallback? onTap, VoidCallback? onDeleted})
      : this._(label: label, variant: _ChipVariant.selected, icon: icon, onTap: onTap, onDeleted: onDeleted);

  const AppChip.status(String label, Color color, {IconData? icon, VoidCallback? onTap})
      : this._(label: label, variant: _ChipVariant.status, icon: icon, onTap: onTap, onDeleted: null);

  Color? get _textColor => variant == _ChipVariant.selected ? AppTheme.primary500 : AppTheme.n700;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: variant == _ChipVariant.selected ? AppTheme.primary50 : AppTheme.n100,
        borderRadius: BorderRadius.circular(6.0),
        border: variant == _ChipVariant.selected ? Border.all(color: AppTheme.primary500) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: _textColor), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: AppTheme.caption.copyWith(color: _textColor, fontWeight: variant == _ChipVariant.selected ? FontWeight.w600 : null))),
        if (onDeleted != null) ...[const SizedBox(width: 4), GestureDetector(onTap: onDeleted, child: Icon(Icons.close, size: 12, color: _textColor))],
      ]),
    );
    if (onTap != null) return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6.0), child: chip));
    return chip;
  }
}

enum _ChipVariant { default_, selected, status }
