import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../router/app_router.dart';

/// API 客户端(全局单例)
class ApiClient {
  // ===== 单例模式 =====
  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  late final Dio dio;

  // 加密存储(保险柜)
  static const _storage = FlutterSecureStorage();

  // refresh 锁:true 表示正在 refresh,其他 401 请求要等
  bool _isRefreshing = false;

  // 等待队列:存储那些 401 之后等新 token 重试的请求
  final List<_PendingRequest> _pendingQueue = [];

  // 专门用来调 /auth/refresh 的 dio(不走拦截器,避免死循环)
  late final Dio _refreshDio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _refreshDio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // ===== 认证拦截器(请求前自动加 Authorization 头) =====
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 从 FlutterSecureStorage 读 access_token，自动附加 Authorization header
        final token = await _storage.read(key: 'access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      // ===== 401 自动刷新队列（Token Rotation）=====
      //
      // 时序:
      //   请求   → 401 ?
      //     │        └─ 是 → 正在 refresh? (_isRefreshing)
      //     │                    ├─ true  → 入队等待 (_pendingQueue)
      //     │                    └─ false → 发起 POST /auth/refresh
      //     │                                  ├─ 成功 → 存新 token
      //     │                                  │       → 重放当前请求
      //     │                                  │       → 逐个重放队列 (_processPendingQueue)
      //     │                                  └─ 失败 → 清 secure storage
      //     │                                          → 跳转 /login
      //     │                                          → 拒绝队列中所有请求
      //     └─ 否 → 正常返回
      //
      // 关键设计:
      //   - _isRefreshing 锁: 防止并发 401 都去调 refresh（只发一次）
      //   - _pendingQueue: 刷新期间的请求不丢失，token 更新后自动重试
      //   - _refreshDio: 独立 Dio 实例（不走拦截器，避免无限循环）
      //   - refresh 本身返回 401 不重试（/auth/refresh 路径跳过拦截）
      onError: (err, handler) async {
        // 402 = 会员已过期(收费期只读)。全局提示一次,错误照常向上传。
        if (err.response?.statusCode == 402) {
          final detail = err.response?.data is Map
              ? (err.response?.data['detail'] as String?)
              : null;
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(detail ?? '会员已过期,当前为只读模式,请联系续费后继续'),
              backgroundColor: const Color(0xFFB91C1C),
            ));
          return handler.next(err);
        }
        if (err.response?.statusCode != 401) {
          return handler.next(err);
        }

        if (err.requestOptions.path.contains('/auth/refresh')) {
          return handler.next(err);
        }

        if (_isRefreshing) {
          _pendingQueue.add(_PendingRequest(err.requestOptions, handler));
          return;
        }

        _isRefreshing = true;
        try {
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken == null || refreshToken.isEmpty) {
            await _clearTokensAndReject(handler, err);
            return;
          }

          final response = await _refreshDio.post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );

          final newAccess = response.data['access_token'] as String;
          final newRefresh = response.data['refresh_token'] as String;

          await _storage.write(key: 'access_token', value: newAccess);
          await _storage.write(key: 'refresh_token', value: newRefresh);

          final retryResponse = await _retryWithNewToken(
            err.requestOptions,
            newAccess,
          );
          handler.resolve(retryResponse);

          await _processPendingQueue(newAccess);
        } on DioException {
          await _clearTokensAndReject(handler, err);
        } catch (e) {
          await _clearTokensAndReject(handler, err);
        } finally {
          _isRefreshing = false;
        }
      },
    ));

    // ===== 日志拦截器 =====
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
    ));
  }

  /// 用新 token 重试请求
  Future<Response> _retryWithNewToken(
      RequestOptions options, String newAccess) async {
    options.headers['Authorization'] = 'Bearer $newAccess';
    return dio.fetch(options);
  }

  /// 处理等待队列:用新 token 逐个重试
  Future<void> _processPendingQueue(String newAccess) async {
    final queue = List<_PendingRequest>.from(_pendingQueue);
    _pendingQueue.clear();

    for (final req in queue) {
      try {
        final retryResponse = await _retryWithNewToken(req.options, newAccess);
        req.handler.resolve(retryResponse);
      } catch (e) {
        req.handler.next(e is DioException
            ? e
            : DioException(requestOptions: req.options, error: e));
      }
    }
  }

  /// refresh 失败:清保险柜 + 跳回登录页 + 让所有等待的请求都报错
  Future<void> _clearTokensAndReject(
      ErrorInterceptorHandler handler, DioException err) async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'agent_id');
    await _storage.delete(key: 'name');

    // 利用全局 Navigator,自动跳回登录页(无需 BuildContext)
    _redirectToLogin();

    // 让等待队列里的所有请求都报错
    final queue = List<_PendingRequest>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final req in queue) {
      req.handler.next(err);
    }

    handler.next(err);
  }

  /// 跳转到登录页(使用全局 Navigator Key)
  void _redirectToLogin() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return; // App 还没起来,跳不了也没事
    try {
      GoRouter.of(ctx).go('/login');
    } catch (_) {
      // 静默失败,下次启动时闪屏会发现没 token 自动跳登录页
    }
  }
}

/// 等待队列里的一个请求
class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.options, this.handler);
}