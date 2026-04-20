import 'api_client.dart';

/// 元数据服务 - 管理字典类数据(行政区等)
/// 这些数据改动极少,所以加个内存缓存,App 打开后只请求一次
class MetaService {
  static final MetaService instance = MetaService._internal();
  MetaService._internal();

  List<String>? _districts;

  /// 获取行政区字典
  /// - 第一次调用会请求后端
  /// - 后续直接返回缓存
  Future<List<String>> getDistricts({bool forceRefresh = false}) async {
    if (!forceRefresh && _districts != null) {
      return _districts!;
    }
    final response =
        await ApiClient.instance.dio.get('/listings/meta/districts');
    final list = (response.data['districts'] as List).cast<String>();
    _districts = list;
    return list;
  }

  /// 手动清空缓存(用户退出登录时调用)
  void clear() {
    _districts = null;
  }
}