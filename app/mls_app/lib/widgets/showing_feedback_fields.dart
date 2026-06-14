import 'package:flutter/material.dart';

/// 带看客户反馈 4 项表单(带看提交 / 直接带看共用)
/// 满意度、对本房意向、客户反馈文本、真实需求洞察。
/// 父组件持有状态;用 [buildMap] 组装提交用的字段(空值不带)。
class ShowingFeedbackFields extends StatelessWidget {
  final String? satisfaction;
  final ValueChanged<String?> onSatisfaction;
  final String? intentResult;
  final ValueChanged<String?> onIntent;
  final TextEditingController feedbackController;
  final TextEditingController trueNeedsController;

  const ShowingFeedbackFields({
    super.key,
    required this.satisfaction,
    required this.onSatisfaction,
    required this.intentResult,
    required this.onIntent,
    required this.feedbackController,
    required this.trueNeedsController,
  });

  static const satisfactionOptions = ['满意', '一般', '不满意'];
  static const intentOptions = ['有意', '再看看', '排除'];

  static Map<String, dynamic> buildMap({
    String? satisfaction,
    String? intentResult,
    required String customerFeedback,
    required String trueNeeds,
  }) {
    final m = <String, dynamic>{};
    if (satisfaction != null) m['satisfaction'] = satisfaction;
    if (intentResult != null) m['intent_result'] = intentResult;
    if (customerFeedback.trim().isNotEmpty) {
      m['customer_feedback'] = customerFeedback.trim();
    }
    if (trueNeeds.trim().isNotEmpty) m['true_needs'] = trueNeeds.trim();
    return m;
  }

  Widget _chips(
      List<String> options, String? selected, ValueChanged<String?> onChanged) {
    return Wrap(
      spacing: 8,
      children: options
          .map((o) => ChoiceChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (v) => onChanged(v ? o : null),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('客户满意度', style: labelStyle),
      const SizedBox(height: 8),
      _chips(satisfactionOptions, satisfaction, onSatisfaction),
      const SizedBox(height: 16),
      const Text('对本房意向', style: labelStyle),
      const SizedBox(height: 8),
      _chips(intentOptions, intentResult, onIntent),
      const SizedBox(height: 16),
      const Text('客户反馈(选填)', style: labelStyle),
      const SizedBox(height: 8),
      TextField(
        controller: feedbackController,
        maxLines: 3,
        maxLength: 300,
        decoration: const InputDecoration(
            hintText: '客户现场怎么说,哪满意哪不满意...', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      const Text('真实需求洞察(选填)', style: labelStyle),
      const SizedBox(height: 8),
      TextField(
        controller: trueNeedsController,
        maxLines: 2,
        maxLength: 300,
        decoration: const InputDecoration(
            hintText: '你判断的客户真实需求,如"嫌总价高,实际要小户型"',
            border: OutlineInputBorder()),
      ),
    ]);
  }
}
