import 'api_client.dart';

/// 带客申请相关接口
class ShowingRequestService {
  static final ShowingRequestService instance =
      ShowingRequestService._internal();
  ShowingRequestService._internal();

  /// 发起带客申请
  ///
  /// [customerId] 可选 · 如果是从"我的客户"中选中的老客户,带上 customer_id
  /// 透传给后端;新建临时客户场景留空,后端按 manual 流程走。
  Future<String> create({
    required String listingId,
    required String customerSurname,
    required String customerGender,
    required String requirements,
    String? customerId,
  }) async {
    final resp = await ApiClient.instance.dio.post(
      '/showing-requests',
      data: {
        'listing_id': listingId,
        'customer_surname': customerSurname,
        'customer_gender': customerGender,
        'requirements': requirements,
        if (customerId != null && customerId.isNotEmpty)
          'customer_id': customerId,
      },
    );
    return resp.data['request_id'] as String;
  }

  /// 我发出的申请(BA 视角)
  Future<Map<String, dynamic>> listSent({int skip = 0, int limit = 50}) async {
    final resp = await ApiClient.instance.dio.get(
      '/showing-requests/sent',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// 我收到的申请(LA 视角)
  Future<Map<String, dynamic>> listReceived({int skip = 0, int limit = 50}) async {
    final resp = await ApiClient.instance.dio.get(
      '/showing-requests/received',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// 待我审批的数量(角标)
  Future<int> pendingCount() async {
    final resp =
        await ApiClient.instance.dio.get('/showing-requests/pending-count');
    return resp.data['count'] as int;
  }

  /// 单条详情
  Future<Map<String, dynamic>> detail(String requestId) async {
    final resp =
        await ApiClient.instance.dio.get('/showing-requests/$requestId');
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// 审批通过(LA)
  Future<Map<String, dynamic>> approve(String requestId) async {
    final resp = await ApiClient.instance.dio
        .post('/showing-requests/$requestId/approve');
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// 审批拒绝(LA)
  Future<Map<String, dynamic>> reject(
    String requestId, {
    required String reason,
    String? extra,
  }) async {
    final resp = await ApiClient.instance.dio.post(
      '/showing-requests/$requestId/reject',
      data: {
        'reason': reason,
        if (extra != null && extra.isNotEmpty) 'extra': extra,
      },
    );
    return resp.data['data'] as Map<String, dynamic>;
  }
}