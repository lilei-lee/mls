import 'package:dio/dio.dart';
import 'api_client.dart';

/// 模块五:成交确认接口
class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  Dio get _dio => ApiClient.instance.dio;

  /// BA 发起成交确认
  Future<String> initiate({
    required String showingId,
    required int dealPriceYuan,
    required String dealDate, // YYYY-MM-DD
    String? notes,
  }) async {
    final resp = await _dio.post('/transactions', data: {
      'showing_id': showingId,
      'deal_price_yuan': dealPriceYuan,
      'deal_date': dealDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return resp.data['transaction_id'] as String;
  }

  /// 按带看查成交记录(可能 null)
  Future<Map<String, dynamic>?> byShowing(String showingId) async {
    final resp = await _dio.get('/transactions/by-showing/$showingId');
    final data = resp.data['data'];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  /// 详情
  Future<Map<String, dynamic>> detail(String transactionId) async {
    final resp = await _dio.get('/transactions/$transactionId');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 独立填报
  Future<Map<String, dynamic>> laConfirm(
    String transactionId, {
    required int dealPriceYuan,
    required String dealDate,
  }) async {
    final resp = await _dio.post(
      '/transactions/$transactionId/la-confirm',
      data: {
        'deal_price_yuan': dealPriceYuan,
        'deal_date': dealDate,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 手动驳回
  Future<Map<String, dynamic>> laReject(
      String transactionId, String reason) async {
    final resp = await _dio.post(
      '/transactions/$transactionId/la-reject',
      data: {'reason': reason},
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// BA 修改自己填报(驳回后重提)
  Future<Map<String, dynamic>> updateMySubmission(
    String transactionId, {
    int? dealPriceYuan,
    String? dealDate,
    String? notes,
  }) async {
    final resp = await _dio.patch(
      '/transactions/$transactionId/my-submission',
      data: {
        if (dealPriceYuan != null) 'deal_price_yuan': dealPriceYuan,
        if (dealDate != null) 'deal_date': dealDate,
        if (notes != null) 'notes': notes,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// LA 修改自己填报(rejected 后重填)
  Future<Map<String, dynamic>> laUpdateMySubmission(
    String transactionId, {
    required int dealPriceYuan,
    required String dealDate,
  }) async {
    final resp = await _dio.patch(
      '/transactions/$transactionId/my-submission',
      data: {
        'deal_price_yuan': dealPriceYuan,
        'deal_date': dealDate,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// BA 撤回
  Future<Map<String, dynamic>> cancel(String transactionId,
      {String? reason}) async {
    final resp = await _dio.post(
      '/transactions/$transactionId/cancel',
      data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 成交待办列表
  Future<Map<String, dynamic>> listPending() async {
    final resp = await _dio.get('/transactions/pending');
    return Map<String, dynamic>.from(resp.data);
  }

  /// BA 等待 LA 确认列表
  Future<Map<String, dynamic>> listPendingBa() async {
    final resp = await _dio.get('/transactions/pending', queryParameters: {'filter': 'ba'});
    return Map<String, dynamic>.from(resp.data);
  }

  /// 工作台角标
  Future<int> pendingCount() async {
    final resp = await _dio.get('/transactions/pending-count');
    return resp.data['count'] as int;
  }
}

/// 房源状态切换接口(模块二 V5:LA 交易状态流转)
class ListingStatusService {
  ListingStatusService._();
  static final ListingStatusService instance = ListingStatusService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<Map<String, dynamic>> markDepositPaid(
    String listingId, {
    int? depositAmountYuan,
    String? note,
  }) async {
    final resp = await _dio.post(
      '/listings/$listingId/mark-deposit-paid',
      data: {
        if (depositAmountYuan != null)
          'deposit_amount_yuan': depositAmountYuan,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  Future<Map<String, dynamic>> markTransactionOngoing(
    String listingId, {
    String? note,
  }) async {
    final resp = await _dio.post(
      '/listings/$listingId/mark-transaction-ongoing',
      data: {
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  Future<Map<String, dynamic>> rollbackToOnSale(
    String listingId,
    String reason,
  ) async {
    final resp = await _dio.post(
      '/listings/$listingId/rollback-to-on-sale',
      data: {'reason': reason},
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }
}