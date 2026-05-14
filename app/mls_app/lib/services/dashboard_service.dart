import 'package:dio/dio.dart';
import 'api_client.dart';

/// 工作台聚合数据
class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  Dio get _dio => ApiClient.instance.dio;

  /// 拉取 4 个数字卡片的聚合数据
  Future<Map<String, dynamic>> summary() async {
    final resp = await _dio.get('/dashboard/summary');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// Day 11 · 拉取逐条待办列表
  /// 返 { todos: [...], total: N }
  Future<Map<String, dynamic>> todos() async {
    final resp = await _dio.get('/dashboard/todos');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// Day 11 · 拉取过去 24 小时的事件流
  /// 返 { events: [...], total: N }
  Future<Map<String, dynamic>> recentEvents() async {
    final resp = await _dio.get('/dashboard/recent-events');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// V6 数据大屏聚合接口 — 7 张卡全部数据
  Future<Map<String, dynamic>> v6() async {
    final resp = await _dio.get('/dashboard/v6');
    return Map<String, dynamic>.from(resp.data['data']);
  }
}