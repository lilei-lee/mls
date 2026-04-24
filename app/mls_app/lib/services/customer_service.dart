import 'package:dio/dio.dart';
import 'api_client.dart';

/// 客户管理 Service · Day 12 新增
///
/// 对应后端 /api/v1/customers/* 系列接口
class CustomerService {
  CustomerService._();
  static final CustomerService instance = CustomerService._();

  Dio get _dio => ApiClient.instance.dio;

  // ========== 基础 CRUD ==========

  /// 创建客户
  /// 返 { customer_id, surname, gender, phone, requirements, ... }
  Future<Map<String, dynamic>> create({
    required String surname,
    required String gender,
    String? phone,
    String? requirements,
  }) async {
    final resp = await _dio.post('/customers', data: {
      'surname': surname,
      'gender': gender,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (requirements != null && requirements.isNotEmpty)
        'requirements': requirements,
    });
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 我的客户列表 · 按 updated_at 降序
  /// 返 { items: [...], total: N }
  Future<Map<String, dynamic>> listMine() async {
    final resp = await _dio.get('/customers/mine');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 客户详情
  Future<Map<String, dynamic>> detail(String customerId) async {
    final resp = await _dio.get('/customers/$customerId');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 更新客户基础信息(部分字段)
  Future<Map<String, dynamic>> update(
    String customerId, {
    String? surname,
    String? gender,
    String? phone,
    String? requirements,
  }) async {
    final payload = <String, dynamic>{};
    if (surname != null) payload['surname'] = surname;
    if (gender != null) payload['gender'] = gender;
    if (phone != null) payload['phone'] = phone;
    if (requirements != null) payload['requirements'] = requirements;

    final resp = await _dio.patch('/customers/$customerId', data: payload);
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 添加一条跟进记录
  Future<Map<String, dynamic>> addMemo(String customerId, String text) async {
    final resp = await _dio.post(
      '/customers/$customerId/memo',
      data: {'text': text},
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 标记已结单
  Future<Map<String, dynamic>> close(String customerId) async {
    final resp = await _dio.patch('/customers/$customerId/close');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 客户时间线(关联的申请/带看/成交事件)
  /// 返 { customer, events: [...], stats: {...} }
  Future<Map<String, dynamic>> timeline(String customerId) async {
    final resp = await _dio.get('/customers/$customerId/timeline');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  // ========== 熟人判断 ==========

  /// 能否对某房直接发起带看?
  /// 返 { can_direct: bool, listing_agent?: {...}, reason?: string }
  Future<Map<String, dynamic>> canDirectShowing(String listingId) async {
    final resp = await _dio.get(
      '/showings/can-direct',
      queryParameters: {'listing_id': listingId},
    );
    return Map<String, dynamic>.from(resp.data['data']);
  }
}