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
}