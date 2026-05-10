import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool showStatusDot;
  final Color? statusColor;

  const AppAvatar({super.key, required this.name, this.size = 40, this.showStatusDot = false, this.statusColor});

  static const _colors = [AppTheme.primary500, AppTheme.gold500, AppTheme.accentCyan, AppTheme.accentPurple];

  Color _hashColor() => _colors[name.isNotEmpty ? name.codeUnitAt(0) % _colors.length : 0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        if (name.isEmpty)
          Container(
            width: size, height: size,
            decoration: BoxDecoration(color: AppTheme.n100, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.person_outline, size: size * 0.5, color: AppTheme.n500),
          )
        else
          Container(
            width: size, height: size,
            decoration: BoxDecoration(color: _hashColor().withValues(alpha: 0.15), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(name[0].toUpperCase(),
                style: AppTheme.caption.copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: _hashColor())),
          ),
        if (showStatusDot)
          Positioned(right: 0, bottom: 0, child: Container(width: size * 0.3, height: size * 0.3,
              decoration: BoxDecoration(color: statusColor ?? AppTheme.success, shape: BoxShape.circle, border: Border.all(color: AppTheme.n0, width: 2)))),
      ]),
    );
  }
}
