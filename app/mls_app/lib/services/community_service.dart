/// 小区服务 — 后端路由: /api/v1/communities/*
/// 被 community_detail_screen、shared listings filter 使用
import 'package:dio/dio.dart';
import 'api_client.dart';

/// 小区库接口
class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  Dio get _dio => ApiClient.instance.dio;

  /// 搜索小区(可选按行政区过滤)
  Future<List<Map<String, dynamic>>> search({
    required String query,
    String? district,
    int limit = 10,
  }) async {
    final resp = await _dio.get('/communities/search', queryParameters: {
      'q': query,
      if (district != null && district.isNotEmpty) 'district': district,
      'limit': limit,
    });
    return (resp.data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// 新增小区
  Future<String> create({
    required String name,
    required String district,
    int? builtYear,
    int? buildingCount,
  }) async {
    final resp = await _dio.post('/communities', data: {
      'name': name,
      'district': district,
      'built_year': ?builtYear,
      'building_count': ?buildingCount,
    });
    return resp.data['community_id'] as String;
  }

  /// 查单个小区
  Future<Map<String, dynamic>> detail(String communityId) async {
    final resp = await _dio.get('/communities/$communityId');
    return Map<String, dynamic>.from(resp.data['data']);
  }
}