import 'package:dio/dio.dart';
import 'api_client.dart';

/// 协作聚合 Service · Day 13 新增
///
/// 对应后端 /api/v1/collaborations/* 系列接口
class CollaborationService {
  CollaborationService._();
  static final CollaborationService instance = CollaborationService._();

  Dio get _dio => ApiClient.instance.dio;

  /// 查我的协作列表
  /// role: 'buyer' (我作为 BA) | 'seller' (我作为 LA)
  /// 返 { items: [...], total: N }
  Future<Map<String, dynamic>> listMine(String role) async {
    final resp = await _dio.get(
      '/collaborations/mine',
      queryParameters: {'role': role},
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }
}