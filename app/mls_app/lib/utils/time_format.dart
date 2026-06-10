/// 相对时间文案
///
/// 把 ISO 时间字符串转为相对时间文案（刚刚 / 分钟前 / 小时前 / 天前 / 个月前）。
/// 输入为 null 或解析失败时返回空字符串。
///
/// 示例:
/// ```dart
/// relativeTime('2026-06-10T08:30:00Z') // '3 小时前'
/// relativeTime(null)                   // ''
/// ```
String relativeTime(String? iso) {
  if (iso == null) return '';
  try {
    final t = DateTime.parse(iso);
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${(diff.inDays / 30).floor()} 个月前';
  } catch (_) {
    return '';
  }
}
