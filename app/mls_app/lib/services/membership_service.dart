import '../models/membership.dart';
import 'api_client.dart';

/// 会员状态服务 — 拉取当前经纪人的会员状态
class MembershipService {
  static final MembershipService instance = MembershipService._internal();
  MembershipService._internal();

  /// GET /membership → 会员状态
  Future<Membership> getMembership() async {
    final response = await ApiClient.instance.dio.get('/membership');
    final data = response.data['data'] as Map<String, dynamic>;
    return Membership.fromJson(data);
  }
}
