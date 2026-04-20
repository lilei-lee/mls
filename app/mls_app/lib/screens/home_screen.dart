import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../services/showing_request_service.dart';
import '../widgets/info_card.dart';

/// 登录后的工作台
class HomeScreen extends StatefulWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storage = FlutterSecureStorage();

  late Future<Map<String, dynamic>> _meFuture;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _meFuture = _fetchMe();
    _refreshPendingCount();
  }

  Future<Map<String, dynamic>> _fetchMe() async {
    final response = await ApiClient.instance.dio.get('/me');
    return response.data as Map<String, dynamic>;
  }

  /// 拉取待审批的带客申请数(静默,失败不弹错)
  Future<void> _refreshPendingCount() async {
    try {
      final count = await ShowingRequestService.instance.pendingCount();
      if (mounted) setState(() => _pendingCount = count);
    } catch (_) {
      // 静默
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'agent_id');
    await _storage.delete(key: 'name');

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工作台'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              setState(() {
                _meFuture = _fetchMe();
              });
              _refreshPendingCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _meFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败:${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _meFuture = _fetchMe();
                      });
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final me = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.waving_hand, size: 60, color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                '欢迎回来,${me['name']}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              InfoCard(label: '手机号', value: me['phone'] ?? '-'),
              InfoCard(label: '所属门店', value: me['store_name'] ?? '-'),
              InfoCard(label: '角色', value: _roleLabel(me['role'])),
              InfoCard(label: '状态', value: _statusLabel(me['status'])),
              const SizedBox(height: 32),

              // 房源两个主入口
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/listings/mine'),
                        icon: const Icon(Icons.home_work),
                        label: const Text('我的房源'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/listings/shared'),
                        icon: const Icon(Icons.share),
                        label: const Text('共享房源库'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 带客协作两个入口
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.push('/showing-requests/sent');
                          _refreshPendingCount();
                        },
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('我发出的申请'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: _ReceivedButton(
                        pendingCount: _pendingCount,
                        onTap: () async {
                          await context.push('/showing-requests/received');
                          _refreshPendingCount();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'boss':
        return '老板';
      case 'agent':
        return '经纪人';
      case 'admin':
        return '管理员';
      default:
        return role ?? '-';
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return '正常';
      case 'pending':
        return '待审核';
      case 'banned':
        return '已封禁';
      case 'deleted':
        return '已注销';
      default:
        return status ?? '-';
    }
  }
}

/// "待我审批"按钮(带红点角标)
class _ReceivedButton extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;
  const _ReceivedButton({
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox.expand(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('待我审批'),
          ),
        ),
        if (pendingCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pendingCount > 99 ? '99+' : '$pendingCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}