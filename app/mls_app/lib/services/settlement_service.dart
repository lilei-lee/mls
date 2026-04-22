import 'api_client.dart';

/// 模块五节点⑥ - 奖金结算
///
/// MVP 范围:
/// - list `/pending-my` → 待我处理列表(LA 待付款 + BA 待确认收款,后端合并返)
/// - count `/pending-my-count` → 工作台角标
/// - detail `/{id}` → 详情
/// - laMarkPaid `/la-mark-paid` → LA 标记已付款
///
/// 未实现(技术债):
/// - baConfirmReceived(等 B 对象存储迁完后补,BA 确认收款 + 证据上传)
class SettlementService {
  SettlementService._();
  static final SettlementService instance = SettlementService._();

  /// 拉取"待我操作"结算单列表
  /// 返回 { success, total, items: [...] }
  /// item 字段见 backend settlements._format_lite:
  ///   settlement_id, transaction_id, listing_snapshot,
  ///   counterpart_name, bonus_yuan, deal_price_yuan,
  ///   status, viewer_role(la/ba), created_at
  Future<Map<String, dynamic>> listPendingMy({
    int skip = 0,
    int limit = 50,
  }) async {
    final resp = await ApiClient.instance.dio.get(
      '/settlements/pending-my',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return Map<String, dynamic>.from(resp.data);
  }

  /// 工作台角标:LA 待付 + BA 待确认合计
  Future<int> pendingMyCount() async {
    final resp = await ApiClient.instance.dio.get(
      '/settlements/pending-my-count',
    );
    return (resp.data['count'] as num).toInt();
  }

  /// 结算单详情(viewer-aware)
  Future<Map<String, dynamic>> detail(String settlementId) async {
    final resp = await ApiClient.instance.dio.get(
      '/settlements/$settlementId',
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 标记已付款
  /// note 可选,最多 200 字
  Future<Map<String, dynamic>> laMarkPaid(
    String settlementId, {
    String? note,
  }) async {
    final resp = await ApiClient.instance.dio.post(
      '/settlements/$settlementId/la-mark-paid',
      data: {
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }
}