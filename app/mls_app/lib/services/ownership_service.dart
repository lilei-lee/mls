import 'api_client.dart';

/// 房源归属变更服务 — 当前归属人发起申请(上传委托凭证 + 指定目标)
class OwnershipService {
  static final OwnershipService instance = OwnershipService._();
  OwnershipService._();

  /// 发起归属变更申请。proofDataUrl 为委托协议凭证(base64 data url),可选。
  Future<void> requestOwnershipChange({
    required String listingId,
    required String toPhone,
    String? proofDataUrl,
    String? reason,
  }) async {
    await ApiClient.instance.dio.post('/ownership-changes', data: {
      'listing_id': listingId,
      'to_phone': toPhone,
      if (proofDataUrl != null && proofDataUrl.isNotEmpty) 'proof': proofDataUrl,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }
}
