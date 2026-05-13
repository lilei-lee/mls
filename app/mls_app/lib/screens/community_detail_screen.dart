import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mls_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../widgets/base64_image.dart';

/// V2.2 #4: 小区 3-tab 详情(在售房源 / 成交记录 / 小区档案)
class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});
  @override State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _detailFuture;
  int? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _detailFuture = _fetchDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchDetail() async {
    final r = await ApiClient.instance.dio.get('/communities/${widget.communityId}/detail');
    return r.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchListings({int page = 1, int? room}) async {
    final qp = <String, dynamic>{'page': page, 'page_size': '20'};
    if (room != null) qp['room'] = room;
    final r = await ApiClient.instance.dio.get(
      '/communities/${widget.communityId}/listings', queryParameters: qp);
    return r.data['data'] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('小区详情')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) return const Center(child: Text('加载失败'));
          final data = snap.data!;
          final name = data['name'] ?? '';
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final avgPrice = stats['avg_price'];
          final dealPrice = stats['deal_avg_price'];
          final activeListings = stats['active_listings'] ?? 0;
          final monthlyNew = stats['monthly_new'] ?? 0;

          // 获取扩展字段(从 enrich 或 community_features)
          final bldStart = data['bld_year_start'];
          return Column(children: [
            // ── 头部统计 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: MlsColors.primaryBg),
              child: Column(children: [
                Text(name, style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(data['district'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _statCol('在售均价', avgPrice != null ? '${avgPrice ~/ 100}万/平' : '-'),
                  _statCol('成交均价', dealPrice != null ? '${dealPrice ~/ 100}万/平' : '-'),
                ]),
                const SizedBox(height: 8),
                Text('在售 $activeListings 套 · 月新增 $monthlyNew',
                    style: const TextStyle(fontSize: 12.0, color: Colors.black54)),
                if (bldStart != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(buildInfoLine(data), style: const TextStyle(fontSize: 11.0, color: Colors.black54)),
                  ),
              ]),
            ),

            // ── TabBar ──
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '在售房源'),
                Tab(text: '成交记录'),
                Tab(text: '小区档案'),
              ],
            ),

            // ── TabBarView ──
            Expanded(child: TabBarView(
              controller: _tabController,
              children: [
                _tabListings(),
                _tabDeals(),
                _tabProfile(data),
              ],
            )),
          ]);
        },
      ),
    );
  }

  String buildInfoLine(Map<String, dynamic> data) {
    final parts = <String>[];
    final bld = data['bld_year_start'];
    if (bld != null) parts.add('建成 $bld');
    final pr = data['plot_ratio'];
    if (pr != null) parts.add('容积率 $pr');
    final gr = data['green_ratio'];
    if (gr != null) parts.add('绿化 ${(gr * 100).toStringAsFixed(0)}%');
    return parts.join(' · ');
  }

  Widget _statCol(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.red)),
      Text(label, style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
    ]);
  }

  // ── Tab 1: 在售房源 ──
  Widget _tabListings() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchListings(room: _selectedRoom),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = ((snap.data?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
        return Column(children: [
          // 户型 chip
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('不限'), selected: _selectedRoom == null,
                onSelected: (_) => setState(() => _selectedRoom = null),
              ),
              for (final r in [1, 2, 3, 4])
                ChoiceChip(
                  label: Text(r == 4 ? '4室+' : '$r室'),
                  selected: _selectedRoom == r,
                  onSelected: (_) => setState(() => _selectedRoom = _selectedRoom == r ? null : r),
                ),
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('暂无在售房源', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _listingCard(items[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _listingCard(Map<String, dynamic> item) {
    final lid = item['listing_id'] ?? '';
    final price = item['price_wan'] ?? 0;
    final layout = item['layout'] ?? '';
    final area = item['area_sqm'] ?? '';
    final cover = item['cover_thumbnail'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/listing/$lid'),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: SizedBox(width: 72, height: 72,
                    child: cover != null && cover.isNotEmpty
                        ? Base64Image(dataUrl: cover, fit: BoxFit.cover)
                        : Container(color: MlsColors.borderLight, child: const Icon(Icons.image, color: Colors.grey))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item['building']}-${item['unit']}-${item['room_no']} | $layout',
                      style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${area}㎡ · ${item['floor']}/${item['total_floor']}层',
                      style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
                ]),
              ),
              Text('¥$price万', style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.red)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Tab 2: 成交记录(V3 占位) ──
  Widget _tabDeals() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
        SizedBox(height: 12),
        Text('成交数据即将上线', style: TextStyle(color: Colors.grey, fontSize: 16.0)),
      ]),
    );
  }

  // ── Tab 3: 小区档案 ──
  Widget _tabProfile(Map<String, dynamic> data) {
    // 基础信息行
    final basicRows = <Widget>[];
    final bldS = data['bld_year_start'], bldE = data['bld_year_end'];
    if (bldS != null) basicRows.add(_row('建成年代', bldS == bldE ? '${bldS}年' : '${bldS}-${bldE}年'));
    _addIf(basicRows, '总楼栋', data['total_buildings'], suffix: ' 栋');
    _addIf(basicRows, '总户数', data['total_units'], suffix: ' 户');
    _addIf(basicRows, '容积率', data['plot_ratio']);
    final gr = data['green_ratio'];
    if (gr != null) basicRows.add(_row('绿化率', '${(gr * 100).toStringAsFixed(0)}%'));

    final propRows = <Widget>[];
    _addIf(propRows, '物业公司', data['property_company']);
    _addIf(propRows, '物业费', data['property_fee_yuan'], suffix: ' 元/㎡/月');
    final bt = data['building_types'];
    if (bt is List && bt.isNotEmpty) propRows.add(_row('楼栋类型', bt.join(', ')));

    final aroundRows = <Widget>[];
    _addIf(aroundRows, '供暖', data['heating_type']);
    _addIf(aroundRows, '小学', data['primary_school']);
    _addIf(aroundRows, '初中', data['middle_school']);
    _addIf(aroundRows, '高速', data['nearest_highway']);
    _addIf(aroundRows, '高铁站', data['nearest_train_station']);
    _addIf(aroundRows, '商超', data['nearby_market'], isList: true);
    _addIf(aroundRows, '医院', data['nearby_hospital'], isList: true);
    _addIf(aroundRows, '车位', data['parking_total'], suffix: ' 个');
    _addIf(aroundRows, '车户比', data['parking_ratio']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (basicRows.isNotEmpty)
          _expTile('基础属性', Icons.home_outlined, basicRows),
        if (propRows.isNotEmpty)
          _expTile('物业信息', Icons.business_outlined, propRows),
        if (aroundRows.isNotEmpty)
          _expTile('周边配套', Icons.map_outlined, aroundRows),
        _expTile('周边对比', Icons.compare_arrows_outlined, [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: MlsColors.borderLight, borderRadius: BorderRadius.circular(4.0)),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 14, color: Colors.grey),
              SizedBox(width: 8),
              Text('即将上线', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
            ]),
          ),
        ]),
      ],
    );
  }

  Widget _expTile(String title, IconData icon, List<Widget> children) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: Icon(icon, size: 20, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(children: children))],
    );
  }

  void _addIf(List<Widget> rows, String label, dynamic val, {String? suffix, bool isList = false}) {
    if (val == null || (val is String && val.isEmpty)) return;
    if (val is List && val.isEmpty) return;
    final text = isList ? (val as List).join(', ') : suffix != null ? '$val$suffix' : val.toString();
    rows.add(_row(label, text));
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12.0))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500))),
    ]),
  );
}
