/// V2.2 #3: LA 视角带看汇总卡片数据
class ListingShowingSummary {
  final String showingRequestId;
  final String baId;
  final String baName;
  final String? baPhone;
  final String customerName;
  final String? customerDemand;
  final DateTime createdAt;
  final DateTime latestEventAt;
  final String currentStatus;
  final String currentStatusLabel;

  ListingShowingSummary({
    required this.showingRequestId,
    required this.baId,
    required this.baName,
    this.baPhone,
    required this.customerName,
    this.customerDemand,
    required this.createdAt,
    required this.latestEventAt,
    required this.currentStatus,
    required this.currentStatusLabel,
  });

  factory ListingShowingSummary.fromJson(Map<String, dynamic> json) {
    return ListingShowingSummary(
      showingRequestId: json['showing_request_id'] ?? '',
      baId: json['ba_id'] ?? '',
      baName: json['ba_name'] ?? '',
      baPhone: json['ba_phone'],
      customerName: json['customer_name'] ?? '',
      customerDemand: json['customer_demand'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      latestEventAt: DateTime.tryParse(json['latest_event_at'] ?? '') ?? DateTime.now(),
      currentStatus: json['current_status'] ?? '',
      currentStatusLabel: json['current_status_label'] ?? '',
    );
  }
}
