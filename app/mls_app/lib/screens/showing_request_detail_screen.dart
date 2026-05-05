import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/showing_request.dart';
import '../services/api_client.dart';
import '../services/showing_request_service.dart';
import '../services/showing_service.dart';
import '../services/transaction_service.dart';
import '../widgets/status_labels.dart';

/// 带客申请详情页
class ShowingRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const ShowingRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ShowingRequestDetailScreen> createState() =>
      _ShowingRequestDetailScreenState();
}

class _ShowingRequestDetailScreenState
    extends State<ShowingRequestDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  Future<Map<String, dynamic>?>? _showingFuture;
  Future<Map<String, dynamic>?>? _transactionFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ShowingRequestService.instance.detail(widget.requestId);
      _showingFuture = ShowingService.instance
          .byRequest(widget.requestId)
          .catchError((_) => null);
      _transactionFuture = _showingFuture!.then((showing) {
        if (showing != null && showing['status'] == 'confirmed') {
          return TransactionService.instance
              .byShowing(showing['showing_id'] as String)
              .catchError((_) => null);
        }
        return null;
      });
    });
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('同意带客申请'),
        content: const Text('通过后双方身份互通,对方可联系您。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('同意', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await ShowingRequestService.instance.approve(widget.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已同意,双方身份已公开')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reject() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => const _RejectDialog(),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      await ShowingRequestService.instance.reject(
        widget.requestId,
        reason: result['reason']!,
        extra: result['extra'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已拒绝')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败:$msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: phone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已复制号码到剪贴板:$phone')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制号码到剪贴板:$phone')),
        );
      }
    }
  }

  Future<void> _goSubmitShowing(Map<String, dynamic> snapshot) async {
    final result = await context.push<bool>('/showing/submit', extra: {
      'request_id': widget.requestId,
      'snapshot': snapshot,
    });
    if (result == true) _reload();
  }

  Future<void> _goConfirmShowing(String showingId) async {
    final result = await context.push<bool>('/showing/$showingId/confirm');
    if (result == true) _reload();
  }

  Future<void> _goInitiateTransaction(
    String showingId,
    Map<String, dynamic> snapshot,
    String listingId,
  ) async {
    // 前置检查:listing 必须是 deposit_paid 或 transaction_ongoing
    try {
      final resp = await ApiClient.instance.dio.get('/listings/$listingId');
      final listingStatus = resp.data['data']['status'] as String;
      if (listingStatus != 'deposit_paid' &&
          listingStatus != 'transaction_ongoing') {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber,
                color: Colors.orange, size: 48),
            title: const Text('房源尚未进入交易阶段'),
            content: const Text(
              '发起成交确认前,Listing Agent 必须先把房源标记为「定金已付」或「成交进行中」。\n\n请联系 LA 完成此操作后再发起。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? e.message ?? '网络错误';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('状态检查失败:$msg')));
      return;
    }

    final result = await context.push<bool>('/transaction/initiate', extra: {
      'showing_id': showingId,
      'snapshot': snapshot,
      'listing_price_wan': snapshot['price_wan'],
    });
    if (result == true) _reload();
  }

  Future<void> _goTransactionDetail(String transactionId) async {
    final result = await context.push<bool>('/transaction/$transactionId');
    if (result == true) _reload();
  }
  
  // Day 16:直接带看(1:N)入口
  Future<void> _goDirectShowing(Map<String, dynamic> snapshot) async {
    // 取当前申请的客户标签
    final data = await _future;
    final surname = (data['customer_surname'] ?? '') as String;
    final gender = (data['customer_gender'] ?? 'male') as String;
    final customerLabel = '$surname${gender == 'male' ? '先生' : '女士'}';
    final listingId = data['listing_id'] as String;

    if (!mounted) return;
    final result = await context.push<bool>(
      '/showings/direct/new',
      extra: {
        'listing_id': listingId,
        'snapshot': snapshot,
        'customer_label': customerLabel,
      },
    );
    if (result == true) _reload();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('带客申请详情')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败:${snap.error}',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _reload, child: const Text('重试')),
                ],
              ),
            );
          }

          final data = snap.data!;
          final status = ShowingRequestStatus.fromString(data['status']);
          final viewerRole = data['viewer_role'] as String;
          final isLA = viewerRole == 'listing_agent';
          final snapshot = Map<String, dynamic>.from(data['listing_snapshot']);
          final counter = Map<String, dynamic>.from(data['counterparty']);
          final listingId = data['listing_id'] as String;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusBanner(status),
              const SizedBox(height: 16),

              _sectionTitle('目标房源'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${snapshot['community']} ${snapshot['building']}号楼${snapshot['unit']}单元${snapshot['room_no']}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${snapshot['layout'] ?? ''} · ${snapshot['area_sqm']}㎡ · ¥${snapshot['price_wan']}万',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('客户信息'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${data['customer_surname']}${data['customer_gender'] == 'male' ? '先生' : '女士'}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('需求',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        data['requirements'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _counterpartySection(counter, status, isLA),
              const SizedBox(height: 16),

              if (status == ShowingRequestStatus.rejected) ...[
                _sectionTitle('拒绝理由'),
                Card(
                  color: Colors.grey.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['reject_reason_text'] ?? '-',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (data['reject_extra'] != null &&
                            data['reject_extra'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '补充说明:${data['reject_extra']}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (isLA && status == ShowingRequestStatus.pending) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _reject,
                          icon: const Icon(Icons.close),
                          label: const Text('拒绝'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _approve,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('同意'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              if (status == ShowingRequestStatus.approved &&
                  counter['phone'] != null &&
                  counter['phone'].toString().isNotEmpty) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(counter['phone']),
                    icon: const Icon(Icons.phone),
                    label: Text(
                      '拨打 ${counter['name']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '点击拨号将调用系统拨号盘,平台会记录该拨号动作',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),

                // 带看记录区
                _sectionTitle('带看记录(节点 ④)'),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _showingFuture,
                  builder: (ctx, s) {
                    if (s.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _showingSection(s.data, isLA, snapshot);
                  },
                ),

                // 模块五:成交确认区
                FutureBuilder<Map<String, dynamic>?>(
                  future: _showingFuture,
                  builder: (ctx, s) {
                    if (s.data == null || s.data!['status'] != 'confirmed') {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _sectionTitle('成交确认(节点 ⑤)'),
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _transactionFuture,
                          builder: (ctx, t) {
                            if (t.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            return _transactionSection(
                              t.data,
                              isLA,
                              s.data!['showing_id'] as String,
                              snapshot,
                              listingId,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ----- 带看记录区 -----

  Widget _showingSection(
    Map<String, dynamic>? showing,
    bool isLA,
    Map<String, dynamic> snapshot,
  ) {
    if (showing == null) {
      if (isLA) {
        return Card(
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('等待 BA 提交带看记录',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          Card(
            color: Colors.orange.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('完成实地带看后,请及时提交带看记录',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _goSubmitShowing(snapshot),
              icon: const Icon(Icons.camera_alt),
              label: const Text('提交带看记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final showingId = showing['showing_id'] as String;
    final status = showing['status'] as String;
    final photoCount = showing['photo_count'] as int? ?? 0;
    final showingTime = _formatTime(showing['showing_time'] as String);
    final rejectReason = showing['reject_reason'] as String?;

    final infoCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _showingStatusChip(status),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('带看时间:$showingTime',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('现场照片:$photoCount 张',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (status == 'rejected' &&
                rejectReason != null &&
                rejectReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '驳回理由:$rejectReason',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (status == 'pending_confirm') {
      return Column(
        children: [
          infoCard,
          const SizedBox(height: 8),
          if (isLA)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _goConfirmShowing(showingId),
                icon: const Icon(Icons.rate_review),
                label: const Text('查看并确认'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('等待 LA 确认中...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ),
        ],
      );
    }

    if (status == 'confirmed') {
      return Column(
        children: [
          infoCard,
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/showing/$showingId/confirm'),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('查看带看详情'),
            ),
          ),
          // Day 16:1:N 直接带看 · 仅 BA 视角显示
          if (!isLA) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _goDirectShowing(snapshot),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('再次带看(无需重新审批)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (status == 'rejected') {
      return Column(
        children: [
          infoCard,
          const SizedBox(height: 8),
          if (!isLA)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _goSubmitShowing(snapshot),
                icon: const Icon(Icons.refresh),
                label: const Text('重新提交带看记录'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('等待 BA 重新提交...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ),
        ],
      );
    }

    return infoCard;
  }

  // ----- 成交确认区 -----

  Widget _transactionSection(
    Map<String, dynamic>? tx,
    bool isLA,
    String showingId,
    Map<String, dynamic> snapshot,
    String listingId,
  ) {
    if (tx == null) {
      if (isLA) {
        return Card(
          color: Colors.grey.withValues(alpha: 0.08),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('等待 BA 发起成交确认',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          Card(
            color: Colors.amber.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '交易达成后,请发起成交确认。需要房源处于「定金已付」或「成交进行中」状态(由 LA 标记)。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _goInitiateTransaction(showingId, snapshot, listingId),
              icon: const Icon(Icons.gavel),
              label: const Text('发起成交确认'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final txId = tx['transaction_id'] as String;
    final txStatus = tx['status'] as String;
    final baPrice = tx['ba_deal_price_yuan'] as int?;
    final laPrice = tx['la_deal_price_yuan'] as int?;
    final baWan = (baPrice != null)
        ? (baPrice / 10000).toStringAsFixed(1)
        : '-';

    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _transactionStatusChip(txStatus, tx),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('BA 填:¥$baWan 万',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (laPrice != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'LA 填:¥${(laPrice / 10000).toStringAsFixed(1)} 万',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('成交日期:${tx['ba_deal_date'] ?? '-'}',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (txStatus == 'rejected' &&
                tx['reject_reason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '驳回:${tx['reject_reason']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Column(
      children: [
        card,
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => _goTransactionDetail(txId),
            icon: const Icon(Icons.open_in_new),
            label: const Text('查看成交详情'),
          ),
        ),
      ],
    );
  }

  Widget _transactionStatusChip(String status, Map<String, dynamic> tx) {
    // 颜色映射留在本地(语义化色彩),文字大多用 StatusLabels 工具
    late Color color;
    switch (status) {
      case 'pending_la_confirm':
        color = Colors.orange;
        break;
      case 'confirmed':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    // 特殊显示:confirmed 加"· 写入留痕链"、rejected 分自动/手动
    late final String text;
    if (status == 'confirmed') {
      text = '成交已生效 · 写入留痕链';
    } else if (status == 'rejected') {
      text = tx['reject_kind'] == 'price_mismatch'
          ? '系统自动驳回(价格不一致)'
          : 'LA 驳回';
    } else {
      text = StatusLabels.transaction(status);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _showingStatusChip(String status) {
    // 颜色映射留在本地(语义化色彩),文字用 StatusLabels 工具
    late Color color;
    switch (status) {
      case 'pending_la_confirm':
      case 'pending_confirm':
        color = Colors.orange;
        break;
      case 'confirmed':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    // 特殊显示:confirmed 带"· 写入留痕链"强调这是一个链路节点
    final text = status == 'confirmed'
        ? '已确认 · 写入留痕链'
        : StatusLabels.showing(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusBanner(ShowingRequestStatus status) {
    late Color color;
    late IconData icon;
    late String text;
    switch (status) {
      case ShowingRequestStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = '待审批';
        break;
      case ShowingRequestStatus.approved:
        color = Colors.green;
        icon = Icons.check_circle;
        text = '已通过,双方身份已公开';
        break;
      case ShowingRequestStatus.rejected:
        color = Colors.grey;
        icon = Icons.block;
        text = '已拒绝';
        break;
      case ShowingRequestStatus.expired:
        color = Colors.grey;
        icon = Icons.timer_off_outlined;
        text = '已过期 · 7 天未处理自动失效';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _counterpartySection(
    Map<String, dynamic> counter,
    ShowingRequestStatus status,
    bool isLA,
  ) {
    final label = isLA ? '带客经纪人' : '房源归属人';
    final anonymous = counter['anonymous'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: anonymous
                ? Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.visibility_off,
                            color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '审批通过后可见',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            counter['name'] ?? '-',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (counter['store'] != null &&
                          counter['store'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '门店:${counter['store']}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// 拒绝理由对话框
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  String? _selectedReason;
  final _extraController = TextEditingController();

  @override
  void dispose() {
    _extraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('拒绝带客申请'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请选择拒绝理由:',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          ...RejectReasons.all.entries.map((e) {
            return RadioListTile<String>(
              value: e.key,
              groupValue: _selectedReason,
              title: Text(e.value, style: const TextStyle(fontSize: 14)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _selectedReason = v),
            );
          }),
          if (_selectedReason == 'other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _extraController,
              maxLines: 2,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: '请说明原因',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  if (_selectedReason == 'other' &&
                      _extraController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请填写补充说明')),
                    );
                    return;
                  }
                  Navigator.of(context).pop({
                    'reason': _selectedReason!,
                    'extra': _extraController.text.trim(),
                  });
                },
          child: const Text('确定拒绝',
              style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}