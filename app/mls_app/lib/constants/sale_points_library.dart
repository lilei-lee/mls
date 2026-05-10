/// V2.2 #1: 卖点标签 + 客观特征 + 装修选项 预设库
class SalePointsLibrary {
  SalePointsLibrary._();

  // ── 卖点标签分组(UI 展示用) ──
  static const Map<String, List<String>> presetGroups = {
    '税务/产权': ['满五唯一', '满二', '不满二', '红本在手'],
    '教育/位置': ['学区房', '近高铁站', '近商圈'],
    '户型亮点': ['带阳台', '带露台', '带衣帽间', '开放厨房'],
    '社区/配套': ['电梯洋房', '低公摊', '近公园', '采光好'],
    '业主诚意': ['业主诚意', '急售可议', '看房方便'],
    '附赠': ['送车位', '送储物间', '次新房'],
  };

  static final Set<String> allPreset = presetGroups.values.expand((e) => e).toSet();

  static const List<String> objectiveFeatures = [
    '南北通透', '全明格局', '全南户型',
    '客厅朝南', '卧室朝南', '卧室带卫', '明卫',
    '厅带阳台', '卧室阳台', '明厨', '开放厨房',
    '带衣帽间', '带阁楼', '带露台',
  ];

  static const List<String> decorationOptions = [
    '毛坯', '简装', '精装', '豪装', '自住保养好',
  ];

  static const List<String> houseStructureOptions = [
    '平层', '复式', 'Loft', '跃层', '错层', '跃复一体',
  ];

  static const int customMaxLength = 12;
  static const int customMaxCount = 4;
  static final int maxTotal = allPreset.length + customMaxCount;
}
