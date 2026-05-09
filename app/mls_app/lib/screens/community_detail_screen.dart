import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../widgets/base64_image.dart';

/// V2.2 #1: 小区主页 — 18 字段 + 在售房源列表
class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});
  @override State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  late Future<Map<String, dynamic>> _communityFuture;
  late Future<Map<String, dynamic>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _communityFuture = _fetchCommunity();
    _listingsFuture = _fetchListings();
  }

  Future<Map<String, dynamic>> _fetchCommunity() async {
    final r = await ApiClient.instance.dio.get('/communities/${widget.communityId}');
    return r.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchListings() async {
    final r = await ApiClient.instance.dio.get('/listings/shared',
        queryParameters: {'community_id': widget.communityId, 'limit': '50'});
    return r.data as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('小区主页')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _communityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('加载失败:${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final data = snapshot.data!;

          final sections = <Widget>[];

          // ── 基础信息 ──
          final basicRows = <Widget>[];
          final bldStart = data['bld_year_start'];
          final bldEnd = data['bld_year_end'];
          if (bldStart != null) {
            basicRows.add(_row('建成年代', bldStart == bldEnd ? '$bldStart 年' : '$bldStart - $bldEnd 年'));
          }
          _addIf(basicRows, '总楼栋', data['total_buildings'], suffix: ' 栋');
          _addIf(basicRows, '总户数', data['total_units'], suffix: ' 户');
          _addIf(basicRows, '容积率', data['plot_ratio']);
          final gr = data['green_ratio'];
          if (gr != null) basicRows.add(_row('绿化率', '${(gr * 100).toStringAsFixed(0)}%'));
          if (basicRows.isNotEmpty) sections.add(_section('基础信息', basicRows));

          // ── 物业 ──
          final propRows = <Widget>[];
          _addIf(propRows, '物业公司', data['property_company']);
          _addIf(propRows, '物业费', data['property_fee_yuan'], suffix: ' 元/㎡/月');
          final bldTypes = data['building_types'];
          if (bldTypes is List && bldTypes.isNotEmpty) {
            propRows.add(_row('楼栋类型', bldTypes.join(', ')));
          }
          if (propRows.isNotEmpty) sections.add(_section('物业', propRows));

          // ── 供暖 ──
          final heating = data['heating_type']?.toString();
          if (heating != null && heating.isNotEmpty) {
            sections.add(_section('供暖', [_row('供暖方式', heating)]));
          }

          // ── 教育 ──
          final eduRows = <Widget>[];
          _addIf(eduRows, '片区小学', data['primary_school']);
          _addIf(eduRows, '片区初中', data['middle_school']);
          if (eduRows.isNotEmpty) sections.add(_section('教育', eduRows));

          // ── 交通 ──
          final transRows = <Widget>[];
          _addIf(transRows, '最近高速', data['nearest_highway']);
          _addIf(transRows, '最近高铁站', data['nearest_train_station']);
          if (transRows.isNotEmpty) sections.add(_section('交通', transRows));

          // ── 周边 ──
          final nearbyRows = <Widget>[];
          _addListIf(nearbyRows, '周边商超', data['nearby_market']);
          _addListIf(nearbyRows, '周边医院', data['nearby_hospital']);
          if (nearbyRows.isNotEmpty) sections.add(_section('周边', nearbyRows));

          // ── 停车 ──
          final parkRows = <Widget>[];
          _addIf(parkRows, '总车位', data['parking_total'], suffix: ' 个');
          _addIf(parkRows, '车户比', data['parking_ratio']);
          if (parkRows.isNotEmpty) sections.add(_section('停车', parkRows));

          // All fields null → placeholder
          if (sections.isEmpty) {
            sections.add(Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('小区资料补充中', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('经纪人朋友帮忙完善小区信息', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
              ),
            ));
          }

          // ── 在售房源 ──
          sections.add(const SizedBox(height: 8));
          sections.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('本小区在售房源', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ));
          sections.add(
            FutureBuilder<Map<String, dynamic>>(
              future: _listingsFuture,
              builder: (ctx, lsSnapshot) {
                if (lsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                final items = ((lsSnapshot.data?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('本小区暂无在售房源', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  );
                }
                return Column(
                  children: items.map((item) => _CommunityListingCard(item: item)).toList(),
                );
              },
            ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            children: sections,
          );
        },
      ),
    );
  }

  void _addIf(List<Widget> rows, String label, dynamic value, {String? suffix}) {
    if (value == null || (value is String && value.isEmpty)) return;
    final text = suffix != null ? '$value$suffix' : value.toString();
    rows.add(_row(label, text));
  }

  void _addListIf(List<Widget> rows, String label, dynamic value) {
    if (value is! List || value.isEmpty) return;
    rows.add(_row(label, value.join(', ')));
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...rows,
          ]),
        ),
      ),
    );
  }
}

/// 小区主页内的在售房源迷你卡片
class _CommunityListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CommunityListingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cover = item['cover_thumbnail'] as String?;
    final priceWan = (item['price_wan'] as num?)?.toDouble() ?? 0;
    final layout = item['layout'] ?? '';
    final area = (item['area_sqm'] as num?)?.toDouble() ?? 0;
    final listingId = item['listing_id'] as String? ?? '';
    final salePoints = (item['sale_points'] as List?)?.cast<String>() ?? <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/listing/$listingId'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 72, height: 72,
                  child: cover != null && cover.isNotEmpty
                      ? Base64Image(dataUrl: cover, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${item['building']}-${item['unit']}-${item['room_no']} | $layout',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('${area.toStringAsFixed(0)}㎡ | ${item['floor']}/${item['total_floor']}层',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (salePoints.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(salePoints.take(3).join(' · '),
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ]),
              ),
              Text('¥${priceWan.toStringAsFixed(priceWan == priceWan.roundToDouble() ? 0 : 1)}万',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            ]),
          ),
        ),
      ),
    );
  }
}
