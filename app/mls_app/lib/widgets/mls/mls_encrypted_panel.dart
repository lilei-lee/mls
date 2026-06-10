import 'package:flutter/material.dart';
import '../../theme/mls_animations.dart';
import '../../theme/mls_colors.dart';
import '../../theme/mls_radius.dart';
import '../../theme/mls_shadows.dart';
import '../../theme/mls_typography.dart';
import 'mls_avatar.dart';
import 'mls_status_badge.dart';

/// 单个加密字段
class MlsEncryptedField {
  /// 字段标签 (如 "成交价" "成交日期")
  final String label;

  /// 加密遮罩字符长度 (默认 8 个 ▓)
  final int maskLength;

  const MlsEncryptedField({
    required this.label,
    this.maskLength = 8,
  });
}

/// MLS 反作弊基石加密面板 V1
///
/// 成交确认页核心创新。深色面板 + 扫描线动画 + 半显字段网格。
/// 把"机制服务于信任的演化"产品哲学做成可视、可感的 UI。
///
/// 视觉钩子:
/// - 持续游走的蓝色扫描线 (3s 循环, 暗示加密计算中)
/// - SECURED 绿色徽章 (金融感)
/// - 字段网格: 非敏感字段明文显示, 敏感字段 ▓▓▓ 遮罩 + 锁 icon
/// - 底部富文本说明: 一致 → 揭示 (绿) / 不一致 → 驳回 (黄)
///
/// 用法:
/// ```
/// MlsEncryptedPanel(
///   title: '反作弊基石 · 加密生效',
///   submitterName: '李红',
///   submitterRole: 'BA',
///   visibleFields: {'客户姓氏': '王先生', '付款方式': '商业贷款'},
///   maskedFields: [
///     MlsEncryptedField(label: '成交价', maskLength: 6),
///     MlsEncryptedField(label: '成交日期', maskLength: 8),
///   ],
///   footerText: '你独立录入并提交后，系统自动比对双方价格与日期。',
///   matchHint: '一致 → 双方揭示',
///   mismatchHint: '不一致 → 系统驳回 + 三分支提示',
/// )
/// ```
class MlsEncryptedPanel extends StatefulWidget {
  /// 顶部标题 (如 "反作弊基石 · 加密生效")
  final String title;

  /// 已提交方姓名 (如 "李红")
  final String submitterName;

  /// 已提交方角色 (如 "BA" / "LA")
  final String submitterRole;

  /// 已提交方提交时间提示 (默认 "已加密提交")
  final String submitterStatusText;

  /// 明文可见字段 (key=label, value=明文)
  final Map<String, String> visibleFields;

  /// 加密遮罩字段列表
  final List<MlsEncryptedField> maskedFields;

  /// 底部说明前缀文字
  final String footerText;

  /// 匹配时的绿色提示 (默认 "一致 → 揭示")
  final String matchHint;

  /// 不匹配时的黄色提示 (默认 "不一致 → 驳回")
  final String mismatchHint;

  /// 是否显示扫描线动画 (默认 true)
  final bool showScanLine;

  const MlsEncryptedPanel({
    super.key,
    this.title = '反作弊基石 · 加密生效',
    required this.submitterName,
    required this.submitterRole,
    this.submitterStatusText = '✓ 已加密提交',
    required this.visibleFields,
    required this.maskedFields,
    this.footerText = '你独立录入并提交后，系统自动比对双方价格与日期。',
    this.matchHint = '一致 → 双方揭示',
    this.mismatchHint = '不一致 → 系统驳回 + 三分支提示',
    this.showScanLine = true,
  });

  @override
  State<MlsEncryptedPanel> createState() => _MlsEncryptedPanelState();
}

class _MlsEncryptedPanelState extends State<MlsEncryptedPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: MlsAnimations.scanDuration,
      vsync: this,
    );
    if (widget.showScanLine) _scanController.repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  String _mask(int length) {
    return '▓' * length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: MlsColors.panelDark,
        borderRadius: MlsRadius.cardLg,
        boxShadow: MlsShadows.panelDark,
      ),
      child: ClipRRect(
        borderRadius: MlsRadius.cardLg,
        child: Stack(
          children: [
            // 扫描线
            if (widget.showScanLine)
              AnimatedBuilder(
                animation: _scanController,
                builder: (_, _) {
                  return Positioned.fill(
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        // 扫描线从 -30% → +130% 横向移动
                        final w = constraints.maxWidth;
                        final t = _scanController.value;
                        return Stack(
                          children: [
                            Positioned(
                              left: w * (-0.3 + t * 1.6),
                              top: 0,
                              bottom: 0,
                              width: w * 0.3,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        MlsColors.primary.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            // 主内容
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 15, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamilyFallback:
                                MlsTypography.sansFallback,
                            fontSize: 13,
                            fontWeight: MlsTypography.semibold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const MlsStatusBadge(
                        text: 'SECURED',
                        variant: MlsBadgeVariant.onDark,
                        size: MlsBadgeSize.dense,
                        mono: true,
                        showDot: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 内嵌字段卡片
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 提交方信息
                        Row(
                          children: [
                            MlsAvatar(
                              name: widget.submitterName,
                              size: 22,
                              borderWidth: 1.5,
                              borderColor: MlsColors.bgPanelDarkEnd,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.submitterName} · ${widget.submitterRole}',
                              style: const TextStyle(
                                fontFamilyFallback:
                                    MlsTypography.sansFallback,
                                fontSize: 12,
                                color: MlsColors.textOnDarkMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.submitterStatusText,
                              style: const TextStyle(
                                fontFamily: MlsTypography.monoFamily,
                                fontFamilyFallback:
                                    MlsTypography.monoFallback,
                                fontSize: 9,
                                color: Color(0xFF86EFAC),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 字段网格 2 列
                        _buildFieldGrid(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 底部说明
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline,
                              size: 13, color: Color(0xFF60A5FA)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamilyFallback:
                                    MlsTypography.sansFallback,
                                fontSize: 11,
                                color: MlsColors.textOnDarkMuted,
                                height: 1.6,
                              ),
                              children: [
                                TextSpan(text: widget.footerText),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: widget.matchHint,
                                  style: const TextStyle(
                                      color: Color(0xFF86EFAC)),
                                ),
                                const TextSpan(text: '；'),
                                TextSpan(
                                  text: widget.mismatchHint,
                                  style: const TextStyle(
                                      color: Color(0xFFFBBF24)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldGrid() {
    final allFields = <_FieldEntry>[];
    widget.visibleFields.forEach((k, v) {
      allFields.add(_FieldEntry(label: k, value: v, masked: false));
    });
    for (final f in widget.maskedFields) {
      allFields.add(_FieldEntry(
          label: f.label, value: _mask(f.maskLength), masked: true));
    }

    // 2 列网格, 每行 2 个字段
    final rows = <Widget>[];
    for (var i = 0; i < allFields.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildField(allFields[i])),
            const SizedBox(width: 14),
            Expanded(
              child: i + 1 < allFields.length
                  ? _buildField(allFields[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildField(_FieldEntry f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (f.masked) ...[
              const Icon(Icons.lock_outline,
                  size: 10, color: MlsColors.textOnDarkSubtle),
              const SizedBox(width: 3),
            ],
            Text(
              f.label,
              style: const TextStyle(
                fontFamilyFallback: MlsTypography.sansFallback,
                fontSize: 11,
                color: MlsColors.textOnDarkSubtle,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          f.value,
          style: f.masked
              ? const TextStyle(
                  fontFamily: MlsTypography.monoFamily,
                  fontFamilyFallback: MlsTypography.monoFallback,
                  fontSize: 13,
                  color: Color(0xFF475569),
                  letterSpacing: 2,
                  height: 1,
                )
              : const TextStyle(
                  fontFamilyFallback: MlsTypography.sansFallback,
                  fontSize: 11,
                  fontWeight: MlsTypography.medium,
                  color: MlsColors.textOnDark,
                ),
        ),
      ],
    );
  }
}

class _FieldEntry {
  final String label;
  final String value;
  final bool masked;

  _FieldEntry({required this.label, required this.value, required this.masked});
}
