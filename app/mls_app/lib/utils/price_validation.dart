/// 成交价格单位防错校验
///
/// 返回 null 表示价格在合理范围；非 null 为警告文案。
///
/// 规则:
/// - null 或 ≤0 → null（未输入，不拦截）
/// - < 10000 元 → 可能误把"万元"填成"元"
/// - > 5 亿元 → 明显超出合理范围
String? priceWarning(int? priceYuan) {
  if (priceYuan == null || priceYuan <= 0) return null;
  if (priceYuan < 10000) {
    return '金额过低,您是否误把"万元"填成"元"?请核对后重试';
  }
  if (priceYuan > 500000000) return '金额超出合理范围';
  return null;
}
