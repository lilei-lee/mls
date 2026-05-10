import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/customer_list_screen.dart';
import '../screens/listing_list_screen.dart';
import '../screens/settlement_pending_screen.dart';
import '../screens/collaboration_list_screen.dart';
import '../widgets/network_aware.dart';

/// 应用主 Shell:底部 5 Tab 导航
/// Day 11 新建
class MainShell extends StatefulWidget {
  /// 初始选中的 Tab 索引(0-4),从外部路由传入
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
  }

  final List<_TabSpec> _tabs = const [
    _TabSpec('工作台', Icons.dashboard_outlined, Icons.dashboard),
    _TabSpec('房源', Icons.home_outlined, Icons.home),
    _TabSpec('协作', Icons.handshake_outlined, Icons.handshake),
    _TabSpec('客户', Icons.person_outline, Icons.person),
    _TabSpec('奖金', Icons.monetization_on_outlined, Icons.monetization_on),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NetworkAware(child: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          ListingListScreen(),
          CollaborationListScreen(),
          CustomerListScreen(),
          SettlementPendingScreen(),
        ],
      )),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabSpec(this.label, this.icon, this.activeIcon);
}

/// 占位页:5 个 Tab 先用它填空,后续 Day 11-14 逐个替换为真实内容