"""V2.2 #1: listing 富化 — 辞典 property + community 字段补充"""
from database import db, client

# 从 listings 模块导入的常量(避免循环 import)
DICT_PHYSICAL_FIELDS = ("area_sqm", "floor", "total_floor", "rooms", "halls", "bathrooms")
DICT_OPTIONAL_CLAIM_FIELDS = ("objective_features", "decoration")


def enrich_from_dictionary(result: dict, doc: dict, viewer_id=None) -> None:
    """尝试从辞典 get_property 拿物理字段富化 listing 详情,不抛异常。

    如 viewer_id 与 listing.owner_agent_id 相同(LA 视角),附加 my_last_claim。
    """
    property_code = doc.get("property_code")
    if not property_code:
        return
    try:
        from dictionary_client import DictionaryClient
        prop = DictionaryClient().get_property(property_code)
    except Exception:
        return
    auth = prop.get("authoritative_attrs", {}) or {}
    for field in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS:
        val = auth.get(field)
        if val is not None:
            result[field] = val
    claims_list = prop.get("attribute_claims", []) or []
    if claims_list:
        claims_list_sorted = sorted(claims_list, key=lambda c: c.get("claimed_at") or "")
        for field in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS:
            if result.get(field) is not None:
                continue
            for c in reversed(claims_list_sorted):
                if c.get("field") == field and c.get("value") is not None:
                    result[field] = c["value"]
                    break

    if viewer_id and str(viewer_id) == str(doc.get("owner_agent_id", "")):
        my_claims = [
            c for c in claims_list
            if str(c.get("agent_id", "")) == str(viewer_id)
        ]
        my_claims_sorted = sorted(my_claims, key=lambda c: c.get("claimed_at") or "", reverse=True)
        my_last_claim = {field: None for field in DICT_PHYSICAL_FIELDS + DICT_OPTIONAL_CLAIM_FIELDS}
        for c in my_claims_sorted:
            field = c.get("field")
            if field in my_last_claim and my_last_claim[field] is None:
                my_last_claim[field] = c.get("value")
        result["my_last_claim"] = my_last_claim


def enrich_community_from_dict(result: dict, doc: dict) -> None:
    """从 property_dict 按社区名查 18 字段,富化到 listing 详情。"""
    name = doc.get("community")
    if not name:
        return
    try:
        dict_db = client.get_database("property_dict")
        comm = dict_db["communities"].find_one({"name": name})
        if not comm:
            return
        result["community_features"] = {
            "bld_year_start": comm.get("bld_year_start"),
            "bld_year_end": comm.get("bld_year_end"),
            "total_buildings": comm.get("total_buildings"),
            "total_units": comm.get("total_units"),
            "plot_ratio": comm.get("plot_ratio"),
            "green_ratio": comm.get("green_ratio"),
            "property_company": comm.get("property_company"),
            "property_fee_yuan": comm.get("property_fee_yuan"),
            "building_types": comm.get("building_types"),
            "heating_type": comm.get("heating_type"),
            "primary_school": comm.get("primary_school"),
            "middle_school": comm.get("middle_school"),
            "nearest_highway": comm.get("nearest_highway"),
            "nearest_train_station": comm.get("nearest_train_station"),
            "parking_total": comm.get("parking_total"),
            "parking_ratio": comm.get("parking_ratio"),
        }
    except Exception:
        pass
