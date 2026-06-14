"""
MLS 模块:客户管理(Day 10 新建,Day 15 1:N 带看重构)

职责:
- 客户档案 CRUD(owner_agent_id 归属 BA)
- 跟进记录(memo_entries)
- 客户时间线(关联协作)
- 直接带看(基于历史 approved 申请,1:N 模式下不再造重复申请)

设计原则:轻量,只为"不忘事"服务,不做重 CRM
"""

from datetime import datetime
from typing import Optional, List, Literal
from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator

from database import db
from showings import SatisfactionT, IntentResultT, feedback_fields_from


# ============= 枚举 / 常量 =============

PURPOSE_OPTIONS = ("刚需", "改善", "投资", "婚房", "学区", "养老")
PAYMENT_OPTIONS = ("全款", "商贷", "公积金", "组合贷")
SOURCE_OPTIONS = ("门店", "转介绍", "网络", "老客户", "其他")
GRADE_OPTIONS = ("A", "B", "C")
# 状态流水:新客 → 跟进中 → 已带看 → 成交 / 战败
STATUS_OPTIONS = ("new", "following", "viewed", "deal", "lost")
ACTIVE_STATUSES = ("new", "following", "viewed")  # 在跟客户(未成交未战败)

PurposeT = Literal["刚需", "改善", "投资", "婚房", "学区", "养老"]
PaymentT = Literal["全款", "商贷", "公积金", "组合贷"]
SourceT = Literal["门店", "转介绍", "网络", "老客户", "其他"]
GradeT = Literal["A", "B", "C"]
StatusT = Literal["new", "following", "viewed", "deal", "lost"]


def _parse_ymd(s: Optional[str]) -> Optional[datetime]:
    """'YYYY-MM-DD' → datetime(当天 00:00);None/空 → None。"""
    if not s:
        return None
    return datetime.strptime(s, "%Y-%m-%d")


class IntentCommunity(BaseModel):
    """意向小区:可关联小区库(community_id)或仅存名称(新建/自由填)。"""
    community_id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=50)
    district: Optional[str] = Field(None, max_length=20)


# 升级新增字段集合(create / update 共用,统一抽取/落库)
_PROFILE_FIELDS = (
    "phone_alt", "wechat", "source", "intent_grade",
    "budget_min_wan", "budget_max_wan", "intent_districts",
    "rooms_need", "halls_need", "baths_need", "area_need",
    "purpose", "payment", "tags",
)


# ============= 集合索引 =============

def ensure_customers_indexes():
    """建索引:owner_agent_id(归属查询)+ created_at"""
    customers = db["customers"]
    customers.create_index("owner_agent_id")
    customers.create_index([("owner_agent_id", 1), ("status", 1)])
    customers.create_index([("owner_agent_id", 1), ("next_follow_up_at", 1)])
    customers.create_index([("owner_agent_id", 1), ("intent_grade", 1)])
    customers.create_index("created_at")


# ============= Pydantic 模型 =============

class _CustomerProfileMixin(BaseModel):
    """Create / Update 共用的客户档案字段(均可选)。"""
    phone: Optional[str] = Field(None, pattern=r"^1[3-9]\d{9}$", description="手机号")
    requirements: Optional[str] = Field(None, max_length=200, description="需求简述")
    phone_alt: Optional[str] = Field(None, pattern=r"^1[3-9]\d{9}$", description="备用电话")
    wechat: Optional[str] = Field(None, max_length=50, description="微信")
    source: Optional[SourceT] = Field(None, description="客户来源")
    intent_grade: Optional[GradeT] = Field(None, description="意向等级 A/B/C")
    budget_min_wan: Optional[int] = Field(None, ge=0, le=100000, description="预算最低(万)")
    budget_max_wan: Optional[int] = Field(None, ge=0, le=100000, description="预算最高(万)")
    intent_districts: Optional[List[str]] = Field(None, max_length=17, description="意向区域")
    intent_communities: Optional[List[IntentCommunity]] = Field(None, max_length=20, description="意向小区(关联小区库或新建)")
    rooms_need: Optional[int] = Field(None, ge=0, le=20, description="室")
    halls_need: Optional[int] = Field(None, ge=0, le=10, description="厅")
    baths_need: Optional[int] = Field(None, ge=0, le=10, description="卫")
    area_need: Optional[str] = Field(None, max_length=30, description="面积需求,如80-100㎡")
    purpose: Optional[PurposeT] = Field(None, description="购房目的")
    payment: Optional[PaymentT] = Field(None, description="付款方式")
    tags: Optional[List[str]] = Field(None, max_length=20, description="标签")
    next_follow_up_at: Optional[str] = Field(None, pattern=r"^\d{4}-\d{2}-\d{2}$", description="下次跟进日期")

    @field_validator("tags")
    @classmethod
    def _check_tags(cls, v):
        if v is not None:
            for t in v:
                if not t or not t.strip() or len(t) > 12:
                    raise ValueError("每个标签需 1-12 字")
        return v

    @model_validator(mode="after")
    def _check_budget(self):
        lo, hi = self.budget_min_wan, self.budget_max_wan
        if lo is not None and hi is not None and lo > hi:
            raise ValueError("预算最低不能高于最高")
        return self


class CreateCustomerRequest(_CustomerProfileMixin):
    surname: str = Field(..., min_length=1, max_length=10, description="客户姓氏")
    gender: str = Field(..., pattern="^(male|female)$", description="性别")


class UpdateCustomerRequest(_CustomerProfileMixin):
    surname: Optional[str] = Field(None, min_length=1, max_length=10)
    gender: Optional[str] = Field(None, pattern="^(male|female)$")
    status: Optional[StatusT] = Field(None, description="客户状态流水")
    lost_reason: Optional[str] = Field(None, max_length=100, description="战败原因(status=lost 时)")


# ============= 辅助函数 =============

def _format_customer(doc: dict) -> dict:
    """格式化客户文档给前端"""
    nf = doc.get("next_follow_up_at")
    nf_is_dt = isinstance(nf, datetime)
    return {
        "customer_id": str(doc["_id"]),
        "surname": doc.get("surname", ""),
        "gender": doc.get("gender", ""),
        "phone": doc.get("phone") or "",
        "phone_alt": doc.get("phone_alt") or "",
        "wechat": doc.get("wechat") or "",
        "requirements": doc.get("requirements") or "",
        "source": doc.get("source"),
        "intent_grade": doc.get("intent_grade"),
        "budget_min_wan": doc.get("budget_min_wan"),
        "budget_max_wan": doc.get("budget_max_wan"),
        "intent_districts": doc.get("intent_districts", []),
        "intent_communities": doc.get("intent_communities", []),
        "rooms_need": doc.get("rooms_need"),
        "halls_need": doc.get("halls_need"),
        "baths_need": doc.get("baths_need"),
        "area_need": doc.get("area_need") or "",
        "purpose": doc.get("purpose"),
        "payment": doc.get("payment"),
        "tags": doc.get("tags", []),
        "next_follow_up_at": nf.strftime("%Y-%m-%d") if nf_is_dt else None,
        "is_follow_up_due": bool(nf_is_dt and nf <= datetime.now()),
        "memo_entries": doc.get("memo_entries", []),
        "status": doc.get("status", "new"),
        "lost_reason": doc.get("lost_reason"),
        "created_at": doc["created_at"].isoformat() if doc.get("created_at") else None,
        "updated_at": doc["updated_at"].isoformat() if doc.get("updated_at") else None,
    }


# ============= 业务函数 =============

def _profile_to_doc(req) -> dict:
    """从 Create/Update 请求抽取已设置的档案字段 → DB 字段 dict。
    None = 未提供(跳过);空列表 = 显式清空(保留)。"""
    out = {}
    for f in _PROFILE_FIELDS:
        v = getattr(req, f, None)
        if v is not None:
            out[f] = v
    ics = getattr(req, "intent_communities", None)
    if ics is not None:
        out["intent_communities"] = [ic.model_dump() for ic in ics]
    nf = getattr(req, "next_follow_up_at", None)
    if nf is not None:
        out["next_follow_up_at"] = _parse_ymd(nf)
    return out


def create_customer(current_agent_id: str, req: CreateCustomerRequest) -> dict:
    """BA 创建一个新客户(初始状态:新客)"""
    now = datetime.now()
    doc = {
        "owner_agent_id": ObjectId(current_agent_id),
        "surname": req.surname.strip(),
        "gender": req.gender,
        "phone": req.phone,
        "requirements": (req.requirements or "").strip(),
        "memo_entries": [],
        "status": "new",
        "lost_reason": None,
        "tags": [],
        "intent_districts": [],
        "intent_communities": [],
        "created_at": now,
        "updated_at": now,
    }
    doc.update(_profile_to_doc(req))
    result = db["customers"].insert_one(doc)
    doc["_id"] = result.inserted_id
    return _format_customer(doc)


def list_my_customers(
    current_agent_id: str,
    status: Optional[str] = None,
    grade: Optional[str] = None,
    due_only: bool = False,
    sort: str = "updated_at",
) -> list[dict]:
    """BA 客户列表,支持按状态/等级/待跟进筛选 + 多种排序。"""
    q: dict = {"owner_agent_id": ObjectId(current_agent_id)}
    if status:
        q["status"] = status
    if grade:
        q["intent_grade"] = grade
    if due_only:
        q["next_follow_up_at"] = {"$ne": None, "$lte": datetime.now()}
    sort_map = {
        "updated_at": [("updated_at", -1)],
        "created_at": [("created_at", -1)],
        "grade": [("intent_grade", 1), ("updated_at", -1)],
        "follow_up": [("next_follow_up_at", 1)],
    }
    cursor = db["customers"].find(q).sort(sort_map.get(sort, sort_map["updated_at"]))
    return [_format_customer(doc) for doc in cursor]


def count_my_customers(current_agent_id: str) -> int:
    """BA 在跟客户数(新客/跟进中/已带看,不含成交与战败)"""
    return db["customers"].count_documents({
        "owner_agent_id": ObjectId(current_agent_id),
        "status": {"$in": list(ACTIVE_STATUSES)},
    })


def get_customer_by_id(current_agent_id: str, customer_id: str) -> dict:
    """查客户详情(只能查自己的)"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权查看他人客户")
    return _format_customer(doc)


# UpdateCustomerRequest 已上移到顶部(继承 _CustomerProfileMixin)


def update_customer(
    current_agent_id: str,
    customer_id: str,
    req: UpdateCustomerRequest,
) -> dict:
    """更新客户基础信息"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权修改他人客户")

    # 只更新传了的字段
    updates = {}
    if req.surname is not None:
        updates["surname"] = req.surname.strip()
    if req.gender is not None:
        updates["gender"] = req.gender
    if req.phone is not None:
        updates["phone"] = req.phone
    if req.requirements is not None:
        updates["requirements"] = req.requirements.strip()

    # 档案字段(预算/区域/小区/户型/目的/付款/来源/微信/等级/标签/跟进日期…)
    updates.update(_profile_to_doc(req))

    # 状态流水:战败必须带原因(本次或库里已有)
    if req.status is not None:
        if req.status == "lost" and not (req.lost_reason or doc.get("lost_reason")):
            raise HTTPException(status_code=400, detail="标记战败需填写原因")
        updates["status"] = req.status
        if req.lost_reason is not None:
            updates["lost_reason"] = req.lost_reason.strip()

    if not updates:
        return _format_customer(doc)  # 空 PATCH 返回当前状态

    updates["updated_at"] = datetime.now()
    db["customers"].update_one({"_id": oid}, {"$set": updates})

    doc = db["customers"].find_one({"_id": oid})
    return _format_customer(doc)


class AddMemoRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500, description="跟进记录内容")


def add_memo(current_agent_id: str, customer_id: str, req: AddMemoRequest) -> dict:
    """添加一条跟进记录"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人客户")

    now = datetime.now()
    memo = {
        "text": req.text.strip(),
        "created_at": now.isoformat(),
    }
    db["customers"].update_one(
        {"_id": oid},
        {
            "$push": {"memo_entries": memo},
            "$set": {"updated_at": now},
        },
    )
    doc = db["customers"].find_one({"_id": oid})
    return _format_customer(doc)


def close_customer(current_agent_id: str, customer_id: str) -> dict:
    """标记客户为已结单"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    doc = db["customers"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(doc["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权操作他人客户")

    db["customers"].update_one(
        {"_id": oid},
        {"$set": {
            "status": "lost",
            "lost_reason": doc.get("lost_reason") or "经纪人手动关闭",
            "updated_at": datetime.now(),
        }},
    )
    doc = db["customers"].find_one({"_id": oid})
    return _format_customer(doc)


def get_customer_showings(current_agent_id: str, customer_id: str) -> dict:
    """客户已看房源列表(带每次带看的反馈)。
    从 showing_requests(customer_id) → showings 聚合,按带看时间倒序。
    """
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    customer = db["customers"].find_one({"_id": oid})
    if not customer:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(customer["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权查看他人客户")

    requests = list(db["showing_requests"].find({
        "customer_id": oid,
        "status": {"$ne": "merged_into_prior"},
    }))
    request_ids = [r["_id"] for r in requests]
    showings = list(
        db["showings"].find({"showing_request_id": {"$in": request_ids}})
    ) if request_ids else []

    items = []
    for s in showings:
        st = s.get("showing_time")
        items.append({
            "showing_id": str(s["_id"]),
            "listing_id": str(s["listing_id"]) if s.get("listing_id") else None,
            "listing_snapshot": s.get("listing_snapshot", {}),
            "showing_time": st.isoformat() if isinstance(st, datetime) else None,
            "status": s.get("status"),
            # 客户反馈 4 项(老数据无 customer_feedback 时回退到 notes)
            "satisfaction": s.get("satisfaction"),
            "customer_feedback": s.get("customer_feedback") or s.get("notes", ""),
            "true_needs": s.get("true_needs", ""),
            "intent_result": s.get("intent_result"),
            "notes": s.get("notes", ""),
        })
    items.sort(key=lambda x: x["showing_time"] or "", reverse=True)
    return {"items": items, "total": len(items)}


def get_customer_timeline(current_agent_id: str, customer_id: str) -> dict:
    """查客户时间线:关联的申请 / 带看 / 成交(按时间倒序)"""
    try:
        oid = ObjectId(customer_id)
    except Exception:
        raise HTTPException(status_code=400, detail="客户ID格式错误")

    customer = db["customers"].find_one({"_id": oid})
    if not customer:
        raise HTTPException(status_code=404, detail="客户不存在")
    if str(customer["owner_agent_id"]) != current_agent_id:
        raise HTTPException(status_code=403, detail="无权查看他人客户")

    # 查关联的带客申请(通过 customer_id 字段)
    requests = list(db["showing_requests"].find({
    "customer_id": oid,
    "status": {"$ne": "merged_into_prior"},
}))

    # 查关联的带看(通过申请反查,1:N 模式下一个 req 可能挂多条 showing)
    request_ids = [r["_id"] for r in requests]
    showings = list(
        db["showings"].find({"showing_request_id": {"$in": request_ids}})
    ) if request_ids else []

    # 查关联的成交
    showing_ids = [s["_id"] for s in showings]
    transactions = list(
        db["transactions"].find({"showing_id": {"$in": showing_ids}})
    ) if showing_ids else []

    # 聚合事件流:{type, time, data}
    events = []

    for r in requests:
        events.append({
            "type": "request",
            "time": r["created_at"].isoformat() if r.get("created_at") else None,
            "status": r.get("status"),
            "listing_snapshot": r.get("listing_snapshot", {}),
            "request_id": str(r["_id"]),
        })

    for s in showings:
        events.append({
            "type": "showing",
            "time": s["created_at"].isoformat() if s.get("created_at") else None,
            "status": s.get("status"),
            "showing_id": str(s["_id"]),
            "customer_feedback": s.get("customer_feedback", ""),
            "showing_time": s["showing_time"].isoformat() if s.get("showing_time") else None,
        })

    for t in transactions:
        events.append({
            "type": "transaction",
            "time": t["created_at"].isoformat() if t.get("created_at") else None,
            "status": t.get("status"),
            "transaction_id": str(t["_id"]),
        })

    # 时间倒序
    events.sort(key=lambda e: e.get("time") or "", reverse=True)

    return {
        "customer": _format_customer(customer),
        "events": events,
        "stats": {
            "requests_count": len(requests),
            "showings_count": len(showings),
            "transactions_count": len(transactions),
        },
    }


# ============= 熟人判断(直接带看前置) =============

def can_direct_showing(current_agent_id: str, listing_id: str) -> dict:
    """检查能否对某房直接发起带看

    规则(B 版本):针对同一套房,历史上有过 approved 的申请即可。
    """
    try:
        listing_oid = ObjectId(listing_id)
        agent_oid = ObjectId(current_agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源 ID")

    # 查历史是否对这套房有过 approved 申请(或 auto_approved)
    history = db["showing_requests"].find_one({
        "listing_id": listing_oid,
        "buyer_agent_id": agent_oid,
        "status": {"$in": ["approved", "auto_approved"]},
    })

    if history:
        # 获取 LA 信息(已解密)
        la_doc = db["agents"].find_one({"_id": history.get("listing_agent_id")})
        return {
            "can_direct": True,
            "listing_agent": {
                "agent_id": str(la_doc["_id"]) if la_doc else "",
                "name": la_doc.get("name", "") if la_doc else "",
                "phone": la_doc.get("phone", "") if la_doc else "",
            } if la_doc else None,
            "first_approved_at": history["created_at"].isoformat() if history.get("created_at") else None,
        }
    else:
        return {
            "can_direct": False,
            "reason": "首次对接该房源,请先走申请流程",
        }


# ============= 直接带看(Day 15 1:N 重构) =============

class DirectShowingRequest(BaseModel):
    """直接带看入参(Day 15 简化:不再接受客户字段,从 prior_request 取)"""
    listing_id: str = Field(..., description="目标房源 ID")
    showing_time: str = Field(..., description="实际带看时间 ISO8601")
    photos: list[str] = Field(..., min_length=1, max_length=3, description="现场照片 base64 1-3 张")
    notes: Optional[str] = Field(None, max_length=200, description="备注(经纪人自留)")
    # —— 客户反馈 4 项(与 showings.CreateShowingBody 对齐) ——
    satisfaction: Optional[SatisfactionT] = Field(None, description="客户满意度")
    customer_feedback: Optional[str] = Field(None, max_length=300, description="客户现场反馈")
    true_needs: Optional[str] = Field(None, max_length=300, description="真实需求洞察")
    intent_result: Optional[IntentResultT] = Field(None, description="对本房意向")


def create_direct_showing(current_agent_id: str, req: DirectShowingRequest) -> dict:
    """直接发起带看(Day 15 1:N 重构)

    业务规则:1 客户 + 1 房 = 1 协作。同一 BA 对同一套房的"再次带看"
    不再造新 showing_request,而是复用历史 approved 申请,在它下面挂新 showing。

    动作:
    1. 校验房源状态
    2. 查 prior_request:同房 + 同 BA + status in (approved/auto_approved)
       - 找不到 → 400 引导走正常申请流程
    3. 客户信息从 prior_request 取(不允许换客户)
    4. 在 prior_request 下挂新 showing(status=pending_confirm)
    5. 返回 showing_id
    """
    try:
        listing_oid = ObjectId(req.listing_id)
        agent_oid = ObjectId(current_agent_id)
    except Exception:
        raise HTTPException(status_code=400, detail="无效的房源 ID")

    # 1. 查房源
    listing = db["listings"].find_one({"_id": listing_oid})
    if not listing:
        raise HTTPException(status_code=404, detail="房源不存在")
    # V2.1 #14: sold 专属文案,#15 楼盘辞典实施时改 property 维度
    if listing.get("status") == "sold":
        raise HTTPException(status_code=400, detail="该房源已成交,无法发起新协作")
    if listing.get("status") not in ("on_sale", "deposit_paid", "transaction_ongoing"):
        raise HTTPException(status_code=400, detail="该房源当前不接受带看")
    if listing["owner_agent_id"] == agent_oid:
        raise HTTPException(status_code=400, detail="不能对自己录入的房源直接带看")

    # 2. 查 prior_request(熟人关系):取最早的 approved 申请作为协作锚点
    #    如果有多条(老数据未迁移),取 created_at 最早,与 Day 15 数据迁移脚本逻辑保持一致
    prior_request = db["showing_requests"].find_one(
        {
            "listing_id": listing_oid,
            "buyer_agent_id": agent_oid,
            "status": {"$in": ["approved", "auto_approved"]},
        },
        sort=[("created_at", 1)],
    )
    if not prior_request:
        raise HTTPException(
            status_code=400,
            detail="首次对接该房源,请先走申请流程",
        )

    # 3. 客户信息从 prior_request 取(1:N 模式下不允许换客户)
    customer_surname = prior_request.get("customer_surname", "")
    customer_gender = prior_request.get("customer_gender", "")
    customer_oid = prior_request.get("customer_id")  # 可能为 None(老数据)

    # 4. 解析带看时间
    try:
        showing_time_dt = datetime.fromisoformat(
            req.showing_time.replace("Z", "+00:00")
        )
    except Exception:
        raise HTTPException(status_code=400, detail="showing_time 格式错误,需 ISO8601")

    # 5. 在 prior_request 下挂新 showing(不再造新 showing_request)
    now = datetime.now()
    # Day 16 修订:对齐 submit_showing 字段全集,补 ba_*/la_*/ba_submitted_at 等,
    # 否则 _format_showing 在拉详情时会 KeyError(坑 29)
    showing_doc = {
        "showing_request_id": prior_request["_id"],
        "listing_id": listing_oid,
        "listing_snapshot": prior_request.get("listing_snapshot", {
            "community": listing["community"],
            "building": listing["building"],
            "unit": listing["unit"],
            "room_no": listing["room_no"],
            "layout": listing.get("layout", ""),
            "area_sqm": listing["area_sqm"],
            "price_wan": listing["price_wan"],
        }),
        # 双方信息(对齐 submit_showing)
        "ba_agent_id": agent_oid,
        "ba_agent_name": prior_request.get("buyer_agent_name", ""),
        "ba_agent_phone": prior_request.get("buyer_agent_phone", ""),
        "la_agent_id": listing["owner_agent_id"],
        "la_agent_name": prior_request.get("listing_agent_name", ""),
        # 客户信息(1:N 模式下从 prior_request 取,不允许换)
        "customer_surname": customer_surname,
        "customer_gender": customer_gender,
        "customer_id": customer_oid,
        # 带看内容
        "showing_time": showing_time_dt,
        "photos": req.photos,
        "photo_count": len(req.photos),
        "notes": req.notes or "",
        **feedback_fields_from(req),
        # 状态机字段(对齐 submit_showing)
        "status": "pending_confirm",
        "reject_reason": None,
        "ba_submitted_at": now,
        "la_reviewed_at": None,
        "listing_cycle": None,  # 预留,模块五用
        # 1:N 留痕
        "is_repeat_showing": True,
        # 时间戳
        "created_at": now,
        "updated_at": now,
    }
    showing_result = db["showings"].insert_one(showing_doc)

    # 6. 顺手更新 prior_request 的 updated_at(让协作 Tab 排序能跟上)
    db["showing_requests"].update_one(
        {"_id": prior_request["_id"]},
        {"$set": {"updated_at": now}},
    )

    # 7. 取 LA 信息返给前端(给"等 LA 确认"提示用)
    la_doc = db["agents"].find_one({"_id": listing["owner_agent_id"]})

    return {
        "showing_id": str(showing_result.inserted_id),
        "showing_request_id": str(prior_request["_id"]),
        "skipped_approval": True,
        "reused_prior_request": True,  # Day 15 新增:明示复用了历史申请
        "la_name": la_doc.get("name", "") if la_doc else "",
        "la_phone": la_doc.get("phone", "") if la_doc else "",
    }