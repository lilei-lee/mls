/// API 配置
/// 
/// 开发阶段:电脑局域网 IP(手机真机联调用)
/// 生产阶段:替换成正式域名,比如 https://api.mls.com
class ApiConfig {
  /// 后端服务地址
  /// 
  /// ⚠️ 每次电脑换 WiFi,或者路由器重启后 IP 可能会变
  /// 如果手机连不上,先 ipconfig 查一下当前 IP 是否还是这个
  static const String baseUrl = 'http://192.168.0.101:8000';
  
  /// API 前缀
  static const String apiPrefix = '/api/v1';
  
  /// 完整 API 基础地址
  static String get apiBaseUrl => '$baseUrl$apiPrefix';
  
  /// 请求超时时间(秒)
  static const int connectTimeout = 10;
  static const int receiveTimeout = 10;
}