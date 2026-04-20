/// 带客申请状态
enum ShowingRequestStatus {
  pending('pending', '待审批'),
  approved('approved', '已通过'),
  rejected('rejected', '已拒绝');

  final String value;
  final String label;
  const ShowingRequestStatus(this.value, this.label);

  static ShowingRequestStatus fromString(String v) {
    return ShowingRequestStatus.values.firstWhere(
      (s) => s.value == v,
      orElse: () => ShowingRequestStatus.pending,
    );
  }
}

/// 拒绝理由预设(和后端 REJECT_REASONS 一致)
class RejectReasons {
  static const Map<String, String> all = {
    'mismatch': '客户需求与房源不匹配',
    'inconvenient': '近期不方便看房',
    'near_deal': '房源即将成交',
    'other': '其他',
  };
}