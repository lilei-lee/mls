import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../services/showing_request_service.dart';
import '../services/customer_service.dart';

/// BA 发起带客申请(从共享库房源卡片点击"申请带客"跳转至此)
///
/// Day 16 增强:
/// - 顶部加"从我的客户选" / "本次新建"两个入口
/// - 选中老客户后,姓氏 + 性别切只读,提交时透传 customer_id
/// - 购房需求始终可编辑(本次需求可微调,即便客户档案里没填也能补)
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

  // Day 16:选中的老客户(若选了,姓氏+性别切只读;需求不锁)
  String? _selectedCustomerId;
  String? _selectedCustomerSurname;
  String? _selectedCustomerGender;

  bool get _isFromCustomer => _selectedCustomerId != null;

  @override
  void dispose() {
    _surname.dispose();
    _requirements.dispose();
    super.dispose();
  }

  // ============ 选择老客户 ============

  Future<void> _pickFromCustomers() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _CustomerPickerSheet(),
    );

    if (picked == null) return;

    setState(() {
      _selectedCustomerId = picked['customer_id'] as String;
      _selectedCustomerSurname = (picked['surname'] ?? '') as String;
      _selectedCustomerGender = (picked['gender'] ?? 'male') as String;

      _surname.text = _selectedCustomerSurname!;
      _gender = _selectedCustomerGender;
      // 需求按客户档案预填,但保持可编辑(空了也能填,有了也能改)
      _requirements.text = (picked['requirements'] ?? '') as String;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerSurname = null;
      _selectedCustomerGender = null;
      _surname.clear();
      _gender = null;
      _requirements.clear();
    });
  }

  // ============ 提交 ============

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
        customerId: _selectedCustomerId,
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

  // ============ 顶部"客户来源"区块 ============

  Widget _buildCustomerSourceBlock() {
    if (_isFromCustomer) {
      // 已选中老客户 · 绿色 chip 展示
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '已选客户档案',
                    style: TextStyle(
                        color: AppTheme.colorOnSale,
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_selectedCustomerSurname${_selectedCustomerGender == 'male' ? '先生' : '女士'}',
                    style: const TextStyle(
                        fontSize: 12.0, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _pickFromCustomers,
              child: const Text('换一个'),
            ),
            TextButton(
              onPressed: _clearSelection,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('清除'),
            ),
          ],
        ),
      );
    }

    // 未选 · 两个入口按钮
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '客户来源',
            style: TextStyle(color: Colors.grey, fontSize: 11.0),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromCustomers,
                  icon: const Icon(Icons.contacts_outlined, size: 18),
                  label: const Text('从我的客户选'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null, // 未选状态默认就是新建,按钮置灰提示当前模式
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('本次新建'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '默认为本次新建(填下方表单);选老客户可一键带入信息',
            style: TextStyle(color: Colors.grey, fontSize: 11.0),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.listingSnapshot;
    // Day 16 修订:只锁姓氏+性别(身份属性),需求始终可编辑
    final identityLocked = _isFromCustomer;

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
                          TextStyle(color: Colors.grey, fontSize: 11.0),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${s['community']} ${s['building']}号楼${s['unit']}单元${s['room_no']}',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s['layout'] ?? ''} · ${s['area_sqm']}㎡ · ¥${s['price_wan']}万',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12.0),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Day 16 新增:客户来源区块
            _buildCustomerSourceBlock(),
            const SizedBox(height: 16),

            // 匿名提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '申请审批前双方匿名。审批通过后身份互相公开。',
                      style: TextStyle(fontSize: 11.0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 客户姓氏(选老客户后锁定)
            TextFormField(
              controller: _surname,
              readOnly: identityLocked,
              decoration: InputDecoration(
                labelText: '客户姓氏',
                hintText: '只填姓,如:张',
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
                filled: identityLocked,
                fillColor: identityLocked
                    ? AppTheme.grey200.withValues(alpha: 0.5)
                    : null,
              ),
              maxLength: 5,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请填写客户姓氏';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // 性别(选老客户后锁定)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text('客户性别',
                  style: TextStyle(color: Colors.grey, fontSize: 12.0)),
            ),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('先生'),
                    selected: _gender == 'male',
                    onSelected: identityLocked
                        ? null
                        : (v) {
                            if (v) setState(() => _gender = 'male');
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('女士'),
                    selected: _gender == 'female',
                    onSelected: identityLocked
                        ? null
                        : (v) {
                            if (v) setState(() => _gender = 'female');
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 购房需求(始终可编辑 · 即便选了老客户也能补/改)
            // 提示语在选老客户时切成"可在此补充本次需求"
            TextFormField(
              controller: _requirements,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: identityLocked ? '购房需求(本次)' : '购房需求',
                hintText: identityLocked
                    ? '客户档案的需求可在此补充或修改,只对本次申请生效'
                    : '例如:三居室预算80-100万,看学区,全款',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
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
                    : const Text('提交申请', style: TextStyle(fontSize: 16.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ 子组件:客户选择器 BottomSheet ============

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet();

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final resp = await CustomerService.instance.listMine();
    final items =
        (resp['items'] as List).cast<Map<String, dynamic>>();
    // 1A:只列 active(过滤已结单)
    return items.where((c) {
      final status = (c['status'] ?? 'active') as String;
      return status == 'active';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // 顶部 handle + 标题
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.grey400,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.contacts_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('选择客户',
                      style: TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),

            // 列表
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('加载失败:${snap.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 60, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('还没有客户档案',
                                style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 4),
                            Text('回退本次新建,后续到客户 Tab 录入',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 11.0)),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (ctx, idx) {
                      final c = items[idx];
                      final surname = (c['surname'] ?? '') as String;
                      final gender = (c['gender'] ?? 'male') as String;
                      final requirements =
                          (c['requirements'] ?? '') as String;
                      final phone = (c['phone'] ?? '') as String;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: gender == 'male'
                              ? AppTheme.colorDepositPaid.withValues(alpha: 0.15)
                              : Colors.pink.withValues(alpha: 0.15),
                          child: Icon(
                            gender == 'male' ? Icons.man : Icons.woman,
                            color: gender == 'male'
                                ? Colors.blue
                                : Colors.pink,
                          ),
                        ),
                        title: Text(
                          '$surname${gender == 'male' ? '先生' : '女士'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (requirements.isNotEmpty)
                              Text(
                                requirements,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.0),
                              ),
                            if (phone.isNotEmpty)
                              Text('📞 $phone',
                                  style: const TextStyle(
                                      fontSize: 11.0, color: Colors.grey)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(ctx).pop(c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}