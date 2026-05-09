"""V2.2 #1: sale_points 预设标签库

- 21 个预设标签(6 组)
- 4 个自定义槽位(长度 ≤ 12)
- 总上限 25
- 朝向格局类 7 个已迁到辞典 objective_features,不在此列
"""

TAX_TAGS = ["满五唯一", "满二", "不满二", "红本在手"]

EDU_LOC_TAGS = ["学区房", "近高铁站", "近商圈"]

HOUSE_HIGHLIGHT_TAGS = ["带阳台", "带露台", "带衣帽间", "开放厨房"]

COMMUNITY_TAGS = ["电梯洋房", "低公摊", "近公园", "采光好"]

SELLER_INTENT_TAGS = ["业主诚意", "急售可议", "看房方便"]

BONUS_TAGS = ["送车位", "送储物间", "次新房"]

PRESET_SALE_POINTS = (
    TAX_TAGS
    + EDU_LOC_TAGS
    + HOUSE_HIGHLIGHT_TAGS
    + COMMUNITY_TAGS
    + SELLER_INTENT_TAGS
    + BONUS_TAGS
)  # 共 21 个

MAX_PRESET = len(PRESET_SALE_POINTS)
MAX_CUSTOM = 4
MAX_TOTAL = MAX_PRESET + MAX_CUSTOM  # 25
MAX_CUSTOM_LENGTH = 12


def is_preset(tag: str) -> bool:
    return tag in PRESET_SALE_POINTS


def is_valid_custom(tag: str) -> bool:
    return len(tag) <= MAX_CUSTOM_LENGTH


def validate_sale_points(tags: list[str]) -> None:
    """校验 sale_points:预设或长度≤12 自定义,上限 25。不合法抛 ValueError。"""
    if not isinstance(tags, list):
        raise ValueError("sale_points must be a list")
    if len(tags) > MAX_TOTAL:
        raise ValueError(f"sale_points 最多 {MAX_TOTAL} 个(预设 {MAX_PRESET} + 自定义 {MAX_CUSTOM})")

    custom_count = 0
    for tag in tags:
        if not isinstance(tag, str) or not tag.strip():
            raise ValueError(f"sale_points 元素必须是非空字符串: {tag!r}")
        tag = tag.strip()
        if is_preset(tag):
            continue
        if not is_valid_custom(tag):
            raise ValueError(
                f"自定义标签 '{tag}' 长度不能超过 {MAX_CUSTOM_LENGTH} 字"
            )
        custom_count += 1
        if custom_count > MAX_CUSTOM:
            raise ValueError(f"自定义标签最多 {MAX_CUSTOM} 个,当前至少 {custom_count} 个")
