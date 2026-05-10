"""V2.2 #1: 共享库筛选辅助 — 辞典社区 batch 拉取 + 后端聚合过滤"""
from typing import Optional
from database import db, client


def batch_fetch_communities_by_name(docs: list) -> dict:
    """按 community name 从 property_dict 查社区,返 {name: doc}。"""
    names = list(set(d.get("community", "") for d in docs if d.get("community")))
    if not names:
        return {}
    try:
        dict_db = client.get_database("property_dict")
        comms = list(dict_db["communities"].find({"name": {"$in": names}}))
        return {c["name"]: c for c in comms}
    except Exception:
        return {}


def passes_dict_filters(
    doc: dict,
    props_map: dict,
    community_by_name: dict,
    objective_features: Optional[list[str]],
    decoration: Optional[str],
    heating_type: Optional[str],
    bld_year_min: Optional[int],
    bld_year_max: Optional[int],
    house_structure: Optional[str] = None,
) -> bool:
    """判断 listing 是否满足辞典侧筛选条件。V2.2 #2: 加 house_structure。"""
    prop = props_map.get(doc.get("property_code", "")) or {}
    latest = prop.get("attribute_claims_latest", {}) or {}

    if objective_features:
        claim_of = latest.get("objective_features")
        if not isinstance(claim_of, list):
            return False
        for tag in objective_features:
            if tag not in claim_of:
                return False

    if decoration:
        claim_dec = latest.get("decoration")
        if claim_dec != decoration:
            return False

    if house_structure:
        claim_hs = latest.get("house_structure")
        if claim_hs != house_structure:
            return False

    comm = community_by_name.get(doc.get("community", "")) or {}

    if heating_type:
        if comm.get("heating_type") != heating_type:
            return False

    if bld_year_min is not None or bld_year_max is not None:
        year_start = comm.get("bld_year_start")
        year_end = comm.get("bld_year_end")
        used_year = year_start or year_end
        if used_year is None:
            return False
        if bld_year_min is not None and used_year < bld_year_min:
            return False
        if bld_year_max is not None and used_year > bld_year_max:
            return False

    return True
