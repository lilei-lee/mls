import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _meFuture = _fetchMe();
  }

  Future<Map<String, dynamic>> _fetchMe() async {
    final response = await ApiClient.instance.dio.get('/me');
    return response.data as Map<String, dynamic>;
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