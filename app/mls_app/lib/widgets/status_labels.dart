/// 状态码中文化辅助
/// 后端接口凡返回英文 status 字段的,前端显示时用这里转中文。
/// 缺省的(没映射上的)返回英文原样,方便定位未覆盖的 case。
///
/// Day 16 修订:
/// - 修正 `_showing` 字典首条 key:实际后端用的是 `pending_confirm`,不是 `pending_la_confirm`
///   (后者是成交那边的 key)。Day 6 老代码沿用 `pending_confirm`,Day 15 直接带看也是。
/// - 申请补 `auto_approved`(Day 10 老直接带看路径产生)
class StatusLabels {
  // 房源
  static const _listing = {
    'on_sale': '在售',
    'deposit_paid': '定金已付',
    'transaction_ongoing': '成交进行中',
    'sold': '已成交',
    'offline': '已下架',
  };

  // 带客申请
  static const _showingRequest = {
    'pending': '待审批',
    'approved': '已通过',
    'auto_approved': '已通过(熟人直接带看)',
    'rejected': '已驳回',
    'expired': '已过期',
    'cancelled': '已撤回',
    'merged_into_prior': '已合并(1:N)',
  };

  // 带看记录
  static const _showing = {
    'pending_confirm': '待 LA 确认',
    'confirmed': '已确认',
    'rejected': '已驳回',
  };

  // 成交记录
  static const _transaction = {
    'pending_la_confirm': '待 LA 独立填价',
    'confirmed': '已确认',
    'rejected': '已驳回',
    'cancelled': '已撤回',
  };

  // 奖金结算
  static const _settlement = {
    'pending_payment': '待 LA 付款',
    'pending_receipt': '待 BA 确认收款',
    'settled': '已结清',
    'disputed': '有异议',
  };

  /// 通用转中文(从最常用的合并表里查)
  static String of(String? code) {
    if (code == null || code.isEmpty) return '-';
    return _merged[code] ?? code;
  }

  /// 按业务域精确查
  static String listing(String? code) =>
      _listing[code] ?? code ?? '-';
  static String showingRequest(String? code) =>
      _showingRequest[code] ?? code ?? '-';
  static String showing(String? code) =>
      _showing[code] ?? code ?? '-';
  static String transaction(String? code) =>
      _transaction[code] ?? code ?? '-';
  static String settlement(String? code) =>
      _settlement[code] ?? code ?? '-';

  // 合并所有(注意 rejected/cancelled/confirmed 等重名的,以 _settlement 兜底,无伤大雅)
  static final Map<String, String> _merged = {
    ..._listing,
    ..._showingRequest,
    ..._showing,
    ..._transaction,
    ..._settlement,
  };
}