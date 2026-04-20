import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/showing_request_service.dart';

/// BA 发起带客申请(从共享库房源卡片点击"申请带客"跳转至此)
class ShowingRequestCreateScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> listingSnapshot;

  const ShowingRequestCreateScreen({
    super.key,
    required this.listingId,
    required this.listingSnapshot,
  });

  @override
  State<ShowingRequestCreateScreen> createState() =>
      _ShowingRequestCreateScreenState();
}

class _ShowingRequestCreateScreenState
    extends State<ShowingRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _surname = TextEditingController();
  final _requirements = TextEditingController();
  String? _gender; // 'male' or 'female'
  bool _submitting = false;

  @override
  void dispose() {
    _surname.dispose();
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_gender == null) {
      _snack('请选择客户性别');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ShowingRequestService.instance.create(
        listingId: widget.listingId,
        customerSurname: _surname.text.trim(),
        customerGender: _gender!,
        requirements: _requirements.text.trim(),
      );

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              size: 60, color: Colors.green),
          title: const Text('申请已提交'),
          content: const Text(
            '房东需要审批您的带客申请,\n审批通过后双方身份互相公开,\n可一键拨号联系。',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) context.pop(true); // 返回共享库
                },
                child: const Text('好的'),
              ),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      _snack('申请失败:$msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.listingSnapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('申请带客')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 房源信息卡片
            Card(
              color: Colors.blue.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目标房源',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${s['community']} ${s['building']}号楼${s['unit']}单元${s['room_no']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s['layout'] ?? ''} · ${s['area_sqm']}㎡ · ¥${s['price_wan']}万',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 匿名提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '申请审批前双方匿名。审批通过后身份互相公开。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 客户姓氏
            TextFormField(
              controller: _surname,
              decoration: const InputDecoration(
                labelText: '客户姓氏',
                hintText: '只填姓,如:张',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              maxLength: 5,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请填写客户姓氏';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // 性别
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text('客户性别',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('先生'),
                    selected: _gender == 'male',
                    onSelected: (v) {
                      if (v) setState(() => _gender = 'male');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('女士'),
                    selected: _gender == 'female',
                    onSelected: (v) {
                      if (v) setState(() => _gender = 'female');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 需求描述
            TextFormField(
              controller: _requirements,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '购房需求',
                hintText: '例如:三居室预算80-100万,看学区,全款',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请填写购房需求';
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('提交申请', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}