import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/customer_list_screen.dart';

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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          _PlaceholderPage(title: '房源', subtitle: '我的 / 共享库'),
          _PlaceholderPage(title: '协作', subtitle: '买方协作 / 卖方协作'),
          CustomerListScreen(),
          _PlaceholderPage(title: '奖金', subtitle: '收入 / 支出'),
        ],
      ),
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
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PlaceholderPage({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // 工作台才显示头像入口,其他 Tab 占位留空
          if (title == '工作台')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: '我的',
                icon: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('「我的」页待 Day 14 实现')),
                  );
                },
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            const Text('此页正在建设中',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}