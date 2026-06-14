/// 会员状态 — 对应后端 /api/v1/membership 与 /me 的 membership 字段
class Membership {
  final bool enforced;   // 是否进入收费期(false=免费试用期)
  final bool active;     // 是否拥有完整(写)权限
  final bool readOnly;   // 是否被限制为只读(收费期且已过期)
  final String? expiresAt;  // 会员到期日 yyyy-MM-dd,未开通为 null
  final int? daysLeft;      // 剩余天数,未开通为 null

  const Membership({
    required this.enforced,
    required this.active,
    required this.readOnly,
    this.expiresAt,
    this.daysLeft,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      enforced: json['enforced'] == true,
      active: json['active'] == true,
      readOnly: json['read_only'] == true,
      expiresAt: json['expires_at'] as String?,
      daysLeft: json['days_left'] as int?,
    );
  }

  /// 卡片徽章文案 + 颜色判定用
  /// - 免费期:试用中
  /// - 收费期有效:有效会员
  /// - 收费期过期/未开通:已过期
  String get badgeText {
    if (!enforced) return '试用中';
    return active ? '有效会员' : '已过期';
  }

  /// 副标题:有效期/剩余天数描述
  String get subtitle {
    if (!enforced) return '免费试用期,功能不受限';
    if (active) {
      final left = daysLeft != null ? '剩 $daysLeft 天' : '';
      return expiresAt != null ? '有效期至 $expiresAt $left'.trim() : '会员有效';
    }
    return '续费后恢复全部功能';
  }
}
