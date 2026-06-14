import 'package:dio/dio.dart';
import 'api_client.dart';

/// 模块四续集:带看确认接口
class ShowingService {
  ShowingService._();
  static final ShowingService instance = ShowingService._();

  Dio get _dio => ApiClient.instance.dio;

  /// BA 提交带看记录
  Future<String> submit({
    required String showingRequestId,
    required DateTime showingTime,
    required List<String> photos,
    String? notes,
    Map<String, dynamic>? feedback,
  }) async {
    final resp = await _dio.post('/showings', data: {
      'showing_request_id': showingRequestId,
      'showing_time': showingTime.toIso8601String(),
      'photos': photos,
      'notes': notes ?? '',
      ...?feedback,
    });
    return resp.data['showing_id'] as String;
  }

  /// Day 16:直接带看(1:N 模式)
  ///
  /// 老客户对老房子再次带看,跳过申请审批。
  /// 后端会基于"最早 prior_request"挂新 showing,客户信息从 prior_request 取,
  /// 不允许换客户。
  Future<String> createDirect({
    required String listingId,
    required DateTime showingTime,
    required List<String> photos,
    String? notes,
    Map<String, dynamic>? feedback,
  }) async {
    final resp = await _dio.post('/showings/direct', data: {
      'listing_id': listingId,
      'showing_time': showingTime.toIso8601String(),
      'photos': photos,
      'notes': notes ?? '',
      ...?feedback,
    });
    return resp.data['data']['showing_id'] as String;
  }

  /// 按 request_id 查最新的带看记录(返回 null 表示尚未提交)
  Future<Map<String, dynamic>?> byRequest(String requestId) async {
    final resp = await _dio.get('/showings/by-request/$requestId');
    final data = resp.data['data'];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  /// 按 id 查详情
  Future<Map<String, dynamic>> detail(String showingId) async {
    final resp = await _dio.get('/showings/$showingId');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 确认
  Future<Map<String, dynamic>> confirm(String showingId) async {
    final resp = await _dio.post('/showings/$showingId/confirm');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 驳回
  Future<Map<String, dynamic>> reject(String showingId, String reason) async {
    final resp = await _dio.post(
      '/showings/$showingId/reject',
      data: {'reason': reason},
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 待我确认列表
  Future<Map<String, dynamic>> listPendingConfirm() async {
    final resp = await _dio.get('/showings/pending-confirm');
    return Map<String, dynamic>.from(resp.data);
  }

  /// 工作台角标
  Future<int> pendingConfirmCount() async {
    final resp = await _dio.get('/showings/pending-confirm-count');
    return resp.data['count'] as int;
  }
}