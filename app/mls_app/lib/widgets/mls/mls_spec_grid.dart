import 'package:flutter/material.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_typography.dart';

/// 房源信息 2 列规格网格 V1
///
/// 键 11px / tertiary，值 14px / w600 / primary。
/// 值含数字或 `㎡` → mono + tabularFigures；纯中文 → sans。
///
/// 用法:
/// ```dart
/// MlsSpecGrid(items: [
///   (k: '户型', v: '3室2厅2卫'),
///   (k: '建筑面积', v: '108㎡'),
///   (k: '朝向', v: '南北通透'),
///   (k: '楼层', v: '中 / 18层'),
/// ])
/// ```
///
/// 通常包在 MlsCard(variant: elevated) 里，卡顶用 mono 标签 "SPEC · 房源信息"。
class MlsSpecGrid extends StatelessWidget {
  /// 规格键值对列表
  final List<({String k, String v})> items;

  /// 列间距 (默认 12)
  final double columnSpacing;

  /// 行间距 (默认 14)
  final double rowSpacing;

  const MlsSpecGrid({
    super.key,
    required this.items,
    this.columnSpacing = 12,
    this.rowSpacing = 14,
  });

  /// 是否含数字或 ㎡ → 走 mono
  static bool _needsMono(String value) {
    return RegExp(r'[0-9㎡]').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: columnSpacing,
        mainAxisSpacing: rowSpacing,
        childAspectRatio: 3.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final useMono = _needsMono(item.v);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.k,
              style: TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: MlsColors.textTertiary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.v,
              style: TextStyle(
                fontFamily: useMono ? MlsTypography.monoFamily : null,
                fontFamilyFallback: useMono
                    ? MlsTypography.monoFallback
                    : MlsTypography.sansFallback,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MlsColors.textPrimary,
                fontFeatures: useMono
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
