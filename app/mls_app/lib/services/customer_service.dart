/// 客户管理服务 — 后端路由: /api/v1/customers/*
/// 被 customer_list_screen、customer_detail_screen、customer_new_screen 使用
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
  /// extra 可携带升级后的全部档案字段(预算/意向/户型/目的/分级/标签…)
  Future<Map<String, dynamic>> create({
    required String surname,
    required String gender,
    String? phone,
    String? requirements,
    Map<String, dynamic>? extra,
  }) async {
    final data = <String, dynamic>{
      'surname': surname,
      'gender': gender,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (requirements != null && requirements.isNotEmpty)
        'requirements': requirements,
      ...?extra,
    };
    final resp = await _dio.post('/customers', data: data);
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 我的客户列表(支持筛选/排序)
  /// 返 { items: [...], total: N }
  Future<Map<String, dynamic>> listMine({
    String? status,
    String? grade,
    bool dueOnly = false,
    String? sort,
  }) async {
    final qp = <String, dynamic>{};
    if (status != null) qp['status'] = status;
    if (grade != null) qp['grade'] = grade;
    if (dueOnly) qp['due_only'] = true;
    if (sort != null) qp['sort'] = sort;
    final resp = await _dio.get('/customers/mine', queryParameters: qp);
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 客户详情
  Future<Map<String, dynamic>> detail(String customerId) async {
    final resp = await _dio.get('/customers/$customerId');
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 更新客户(传入任意字段 map:基础信息 / 档案 / status+lost_reason)
  Future<Map<String, dynamic>> update(
    String customerId,
    Map<String, dynamic> fields,
  ) async {
    final resp = await _dio.patch('/customers/$customerId', data: fields);
    return Map<String, dynamic>.from(resp.data['data']);
  }

  /// 客户已看房源列表(带每次带看反馈)
  /// 返 { items: [...], total: N }
  Future<Map<String, dynamic>> showings(String customerId) async {
    final resp = await _dio.get('/customers/$customerId/showings');
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