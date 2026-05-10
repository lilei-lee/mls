/// Q&A 问答线程模型
class QnaThread {
  final String threadId;
  final String question;
  final DateTime questionAt;
  final String askerName;
  final bool askerIdSelf;
  final String status;
  final String? answer;
  final DateTime? answeredAt;
  final String? answererName;
  final bool answererSelf;
  final bool canDelete;

  QnaThread({
    required this.threadId,
    required this.question,
    required this.questionAt,
    required this.askerName,
    required this.askerIdSelf,
    required this.status,
    this.answer,
    this.answeredAt,
    this.answererName,
    required this.answererSelf,
    required this.canDelete,
  });

  factory QnaThread.fromJson(Map<String, dynamic> json) {
    return QnaThread(
      threadId: json['thread_id'] ?? '',
      question: json['question'] ?? '',
      questionAt: DateTime.tryParse(json['question_at'] ?? '') ?? DateTime.now(),
      askerName: json['asker_name'] ?? '',
      askerIdSelf: json['asker_id_self'] == true,
      status: json['status'] ?? 'pending',
      answer: json['answer'],
      answeredAt: json['answered_at'] != null ? DateTime.tryParse(json['answered_at']) : null,
      answererName: json['answerer_name'],
      answererSelf: json['answerer_self'] == true,
      canDelete: json['can_delete'] == true,
    );
  }

  bool get isAnswered => status == 'answered';
}

class QnaListResp {
  final int total;
  final List<QnaThread> items;
  final Map<String, dynamic>? listingBrief;

  QnaListResp({required this.total, required this.items, this.listingBrief});

  factory QnaListResp.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List).map((e) => QnaThread.fromJson(e as Map<String, dynamic>)).toList();
    return QnaListResp(
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: items,
      listingBrief: json['listing_brief'] as Map<String, dynamic>?,
    );
  }
}
