"""V6 数据大屏聚合接口 — 7 张卡后端聚合"""
from datetime import datetime, timedelta
from bson import ObjectId
from database import db


def get_dashboard_v6(agent_id: ObjectId) -> dict:
    now = datetime.now()
    year_start = datetime(now.year, 1, 1)
    month_start = datetime(now.year, now.month, 1)
    days90_ago = now - timedelta(days=90)

    return {
        "bonus": _card1_bonus(agent_id, month_start),
        "yearly_deals": _card2_yearly_deals(agent_id, year_start),
        "yearly_activity": _card3_yearly_activity(agent_id, year_start),
        "funnel": _card4_funnel(agent_id, days90_ago),
        "portfolio": _card5_portfolio(agent_id),
    }


def _card1_bonus(agent_id, month_start):
    recv_pipe = [
        {"$match": {"la_agent_id": agent_id, "status": "paid"}},
        {"$group": {"_id": None, "total": {"$sum": "$bonus_yuan"}, "count": {"$sum": 1}}},
    ]
    recv = list(db["settlements"].aggregate(recv_pipe))
    cumulative_received = recv[0]["total"] if recv else 0
    cumulative_received_count = recv[0]["count"] if recv else 0

    recv_m_pipe = [
        {"$match": {"la_agent_id": agent_id, "status": "paid", "created_at": {"$gte": month_start}}},
        {"$group": {"_id": None, "total": {"$sum": "$bonus_yuan"}}},
    ]
    recv_m = list(db["settlements"].aggregate(recv_m_pipe))
    month_received = recv_m[0]["total"] if recv_m else 0

    paid_pipe = [
        {"$match": {"ba_agent_id": agent_id, "status": "confirmed_receipt"}},
        {"$group": {"_id": None, "total": {"$sum": "$bonus_yuan"}, "count": {"$sum": 1}}},
    ]
    paid = list(db["settlements"].aggregate(paid_pipe))
    cumulative_paid = paid[0]["total"] if paid else 0
    cumulative_paid_count = paid[0]["count"] if paid else 0

    paid_m_pipe = [
        {"$match": {"ba_agent_id": agent_id, "status": "confirmed_receipt", "created_at": {"$gte": month_start}}},
        {"$group": {"_id": None, "total": {"$sum": "$bonus_yuan"}}},
    ]
    paid_m = list(db["settlements"].aggregate(paid_m_pipe))
    month_paid = paid_m[0]["total"] if paid_m else 0

    return {
        "cumulative_received": cumulative_received,
        "cumulative_received_count": cumulative_received_count,
        "cumulative_paid": cumulative_paid,
        "cumulative_paid_count": cumulative_paid_count,
        "month_received": month_received,
        "month_paid": month_paid,
    }


_MONTHS = ["1月", "2月", "3月", "4月", "5月", "6月",
           "7月", "8月", "9月", "10月", "11月", "12月"]


def _card2_yearly_deals(agent_id, year_start):
    pipeline = [
        {"$match": {
            "$or": [{"la_agent_id": agent_id}, {"ba_agent_id": agent_id}],
            "status": "confirmed",
            "confirmed_at": {"$gte": year_start},
        }},
        {"$group": {
            "_id": {"$month": "$confirmed_at"},
            "la_count": {"$sum": {"$cond": [{"$eq": ["$la_agent_id", agent_id]}, 1, 0]}},
            "ba_count": {"$sum": {"$cond": [{"$eq": ["$ba_agent_id", agent_id]}, 1, 0]}},
        }},
    ]
    rows = list(db["transactions"].aggregate(pipeline))
    by_month = {r["_id"]: r for r in rows}

    months = []
    total_la = 0
    total_ba = 0
    for m in range(1, 13):
        r = by_month.get(m, {"la_count": 0, "ba_count": 0})
        months.append({
            "month": _MONTHS[m - 1],
            "la": r["la_count"],
            "ba": r["ba_count"],
        })
        total_la += r["la_count"]
        total_ba += r["ba_count"]

    return {
        "months": months,
        "total_la": total_la,
        "total_ba": total_ba,
        "total_all": total_la + total_ba,
    }


def _card3_yearly_activity(agent_id, year_start):
    show_pipe = [
        {"$match": {
            "$or": [{"la_agent_id": agent_id}, {"ba_agent_id": agent_id}],
            "status": "confirmed",
            "created_at": {"$gte": year_start},
        }},
        {"$group": {"_id": {"$month": "$created_at"}, "count": {"$sum": 1}}},
    ]
    show_rows = list(db["showings"].aggregate(show_pipe))
    show_by_month = {r["_id"]: r["count"] for r in show_rows}

    cust_pipe = [
        {"$match": {
            "owner_agent_id": agent_id,
            "created_at": {"$gte": year_start},
        }},
        {"$group": {"_id": {"$month": "$created_at"}, "count": {"$sum": 1}}},
    ]
    cust_rows = list(db["customers"].aggregate(cust_pipe))
    cust_by_month = {r["_id"]: r["count"] for r in cust_rows}

    months = []
    total_showings = 0
    total_customers = 0
    for m in range(1, 13):
        sc = show_by_month.get(m, 0)
        cc = cust_by_month.get(m, 0)
        months.append({
            "month": _MONTHS[m - 1],
            "showings": sc,
            "customers": cc,
        })
        total_showings += sc
        total_customers += cc

    monthly_avg = round(total_showings / 12, 1)

    return {
        "months": months,
        "total_showings": total_showings,
        "total_customers": total_customers,
        "monthly_avg": monthly_avg,
    }


def _card4_funnel(agent_id, days90_ago):
    def _counts(since):
        f_new = {"owner_agent_id": agent_id}
        f_show = {"ba_agent_id": agent_id, "status": "confirmed"}
        f_deal = {"ba_agent_id": agent_id, "status": "confirmed"}
        if since:
            f_new["created_at"] = {"$gte": since}
            f_show["created_at"] = {"$gte": since}
            f_deal["created_at"] = {"$gte": since}
        new = db["customers"].count_documents(f_new)
        showing = db["showings"].count_documents(f_show)
        deal = db["transactions"].count_documents(f_deal)
        return new, showing, deal

    new_90, showing_90, deal_90 = _counts(days90_ago)
    new_all, showing_all, deal_all = _counts(None)

    total_customers = db["customers"].count_documents({"owner_agent_id": agent_id})
    if total_customers == 0:
        return {
            "ba_only": True,
            "message": "BA perspective funnel, no BA collaboration data",
        }

    def _rate(a, b):
        return round(a / b, 3) if b else 0.0

    return {
        "ba_only": False,
        "schema_warning": "customer_id linkage incomplete, showing raw counts not unique customer funnel",
        "funnel_90days": {"new": new_90, "showing": showing_90, "deal": deal_90},
        "funnel_total": {"new": new_all, "showing": showing_all, "deal": deal_all},
        "showing_rate_90d": _rate(showing_90, new_90),
        "deal_rate_90d": _rate(deal_90, showing_90),
        "overall_90d": _rate(deal_90, new_90),
        "showing_rate_total": _rate(showing_all, new_all),
        "deal_rate_total": _rate(deal_all, showing_all),
        "overall_total": _rate(deal_all, new_all),
    }


def _card5_portfolio(agent_id):
    on_sale = db["listings"].count_documents({"owner_agent_id": agent_id, "status": "on_sale"})
    sold = db["listings"].count_documents({"owner_agent_id": agent_id, "status": "sold"})
    offline = db["listings"].count_documents({"owner_agent_id": agent_id, "status": "offline"})
    history = db["listings"].count_documents({
        "owner_agent_id": agent_id,
        "status": {"$nin": ["on_sale", "sold", "offline"]}
    })
    total = on_sale + sold + offline + history

    return {
        "on_sale": on_sale,
        "sold": sold,
        "offline": offline,
        "history": history,
        "total": total,
    }
