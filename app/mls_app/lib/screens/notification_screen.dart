import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/mls_colors.dart';
import '../theme/mls_typography.dart';
import '../widgets/mls/mls_nav_bar.dart';
import '../widgets/mls/mls_notification_tile.dart';
import '../widgets/mls/mls_segmented_control.dart';

/// 通知数据模型
class NotifItem {
  final int id;
  final String group; // '今天' | '更早'
  final String kind; // '协作' | '成交' | '提醒' | '系统'
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
  final bool hasTraceLink;
  final Map<String, dynamic>? traceData;

  const NotifItem({
    required this.id,
    required this.group,
    required this.kind,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = true,
    this.hasTraceLink = false,
    this.traceData,
  });

  NotifItem copyWith({bool? unread}) => NotifItem(
        id: id,
        group: group,
        kind: kind,
        icon: icon,
        accentColor: accentColor,
        title: title,
        subtitle: subtitle,
        time: time,
        unread: unread ?? this.unread,
        hasTraceLink: hasTraceLink,
        traceData: traceData,
      );
}

/// 消息通知中心 V1
///
/// 集中查看协作/成交/系统消息，标记已读。
class NotificationScreen extends StatefulWidget {
  /// 可选外部提供的通知列表
  final List<NotifItem>? initialItems;

  /// 打开留痕回调
  final void Function(Map<String, dynamic> traceData)? onOpenTrace;

  const NotificationScreen({
    super.key,
    this.initialItems,
    this.onOpenTrace,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late List<NotifItem> _items;
  String _filter = '全部';

  static const _tabs = ['全部', '协作', '成交', '系统'];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems ?? _defaultItems);
  }

  static List<NotifItem> get _defaultItems => [
        NotifItem(
          id: 1,
          group: '今天',
          kind: '协作',
          icon: Icons.handshake,
          accentColor: MlsColors.primary,
          title: '李红 发起了带看申请',
          subtitle: '万达华府 · 3室 · 待你同意',
          time: '15:06',
          unread: true,
          hasTraceLink: true,
          traceData: {'listing': {'name': '万达华府 · 3室朝南'}, 'partner': '李红', 'role': 'BA', 'customer': '客户王先生', 'current': 3},
        ),
        NotifItem(
          id: 2,
          group: '今天',
          kind: '成交',
          icon: LucideIcons.badgeDollarSign,
          accentColor: MlsColors.gold,
          title: '成交确认待你签字',
          subtitle: '与李红 · 中央华府 88㎡ · ¥156万',
          time: '14:20',
          unread: true,
          hasTraceLink: true,
          traceData: {'listing': {'name': '中央华府 · 2室'}, 'partner': '李红', 'role': 'BA', 'customer': '客户刘女士', 'current': 3},
        ),
        NotifItem(
          id: 3,
          group: '今天',
          kind: '提醒',
          icon: LucideIcons.clock,
          accentColor: MlsColors.warning,
          title: '今日 15:00 带看提醒',
          subtitle: '万达华府 · 客户王先生 · 还有 03:28',
          time: '11:32',
          unread: true,
        ),
        NotifItem(
          id: 4,
          group: '今天',
          kind: '系统',
          icon: LucideIcons.shieldCheck,
          accentColor: MlsColors.success,
          title: '「学府花园」奖金已到账',
          subtitle: '¥12,600 · 链路自动结算完成',
          time: '09:48',
          unread: false,
        ),
        NotifItem(
          id: 5,
          group: '更早',
          kind: '协作',
          icon: LucideIcons.userCheck,
          accentColor: MlsColors.primary,
          title: '周丽 完成了带看留痕',
          subtitle: '中央华府 · 客户刘女士 · 已独立留痕',
          time: '昨天',
          unread: false,
        ),
        NotifItem(
          id: 6,
          group: '更早',
          kind: '系统',
          icon: LucideIcons.award,
          accentColor: MlsColors.gold,
          title: '信誉等级提升至 A 级',
          subtitle: '本月成交 4 单 · 协作守约率 100%',
          time: '6月2日',
          unread: false,
        ),
      ];

  int get _unreadCount => _items.where((i) => i.unread).length;

  List<NotifItem> get _filtered {
    final shown = _items.where((i) {
      if (_filter == '全部') return true;
      if (_filter == '系统') return i.kind == '系统' || i.kind == '提醒';
      return i.kind == _filter;
    }).toList();
    return shown;
  }

  Map<String, List<NotifItem>> get _grouped {
    final map = <String, List<NotifItem>>{};
    for (final item in _filtered) {
      map.putIfAbsent(item.group, () => []).add(item);
    }
    return map;
  }

  void _markRead(int id) {
    setState(() {
      _items = _items.map((i) => i.id == id ? i.copyWith(unread: false) : i).toList();
    });
  }

  void _markAllRead() {
    setState(() {
      _items = _items.map((i) => i.copyWith(unread: false)).toList();
    });
  }

  void _handleTap(NotifItem item) {
    _markRead(item.id);
    if (item.hasTraceLink && item.traceData != null && widget.onOpenTrace != null) {
      widget.onOpenTrace!(item.traceData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final groupOrder = ['今天', '更早'].where((g) => groups.containsKey(g)).toList();

    return Scaffold(
      backgroundColor: MlsColors.bgPageStart,
      body: SafeArea(
        child: Column(
          children: [
            // ═══ NavBar ═══
            MlsNavBar(
              title: '消息通知',
              sub: _unreadCount > 0
                  ? '${_unreadCount.toString().padLeft(2, '0')} UNREAD'
                  : 'ALL READ',
              right: GestureDetector(
                onTap: _unreadCount > 0 ? _markAllRead : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '全部已读',
                    style: TextStyle(
                      fontFamilyFallback: MlsTypography.sansFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _unreadCount > 0 ? MlsColors.primary : MlsColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),

            // ═══ 分段控件 ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: MlsSegmentedControl<String>(
                values: _tabs,
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
                variant: MlsSegmentedVariant.pill,
              ),
            ),

            // ═══ 通知列表 ═══
            Expanded(
              child: groups.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        for (final g in groupOrder) ...[
                          // ── 组标题 ──
                          Padding(
                            padding: EdgeInsets.only(left: 2, bottom: 10, top: g == groupOrder.first ? 0 : 8),
                            child: Text(
                              g == '今天' ? 'TODAY · 今天' : 'EARLIER · 更早',
                              style: TextStyle(
                                fontFamily: MlsTypography.monoFamily,
                                fontFamilyFallback: MlsTypography.monoFallback,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                                color: MlsColors.textTertiary,
                              ),
                            ),
                          ),

                          // ── 组内通知项 ──
                          ...List.generate(groups[g]!.length, (i) {
                            final item = groups[g]![i];
                            return Padding(
                              padding: EdgeInsets.only(bottom: i < groups[g]!.length - 1 ? 10 : 0),
                              child: MlsNotificationTile(
                                icon: item.icon,
                                accentColor: item.accentColor,
                                title: item.title,
                                subtitle: item.subtitle,
                                time: item.time,
                                unread: item.unread,
                                hasTraceLink: item.hasTraceLink,
                                onTap: () => _handleTap(item),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MlsColors.primaryBg,
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.bellOff, size: 32, color: MlsColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '没有这类消息',
            style: MlsTypography.cardTitleLg.copyWith(color: MlsColors.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            '切换分类看看其他通知',
            style: MlsTypography.body2.copyWith(color: MlsColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
