"""客户管理路由 -- 拆自 main.py L1140-1210"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_agent
from customers import (
    CreateCustomerRequest, UpdateCustomerRequest, AddMemoRequest,
    create_customer, list_my_customers, get_customer_by_id,
    update_customer, add_memo, close_customer, get_customer_timeline,
)

customers_router = APIRouter(prefix="/api/v1", tags=["customers"])


@customers_router.post("/customers")
def api_create_customer(
    req: CreateCustomerRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """BA 创建一个新客户"""
    data = create_customer(str(current_agent["_id"]), req)
    return {"success": True, "data": data}


@customers_router.get("/customers/mine")
def api_list_my_customers(
    current_agent: dict = Depends(get_current_agent),
):
    """BA 查自己的客户列表"""
    data = list_my_customers(str(current_agent["_id"]))
    return {"success": True, "data": {"items": data, "total": len(data)}}

@customers_router.get("/customers/{customer_id}")
def api_get_customer(
    customer_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """查客户详情"""
    data = get_customer_by_id(str(current_agent["_id"]), customer_id)
    return {"success": True, "data": data}


@customers_router.patch("/customers/{customer_id}")
def api_update_customer(
    customer_id: str,
    req: UpdateCustomerRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """更新客户基础信息"""
    data = update_customer(str(current_agent["_id"]), customer_id, req)
    return {"success": True, "data": data}


@customers_router.post("/customers/{customer_id}/memo")
def api_add_memo(
    customer_id: str,
    req: AddMemoRequest,
    current_agent: dict = Depends(get_current_agent),
):
    """添加跟进记录"""
    data = add_memo(str(current_agent["_id"]), customer_id, req)
    return {"success": True, "data": data}


@customers_router.patch("/customers/{customer_id}/close")
def api_close_customer(
    customer_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """标记客户为已结单"""
    data = close_customer(str(current_agent["_id"]), customer_id)
    return {"success": True, "data": data}


@customers_router.get("/customers/{customer_id}/timeline")
def api_get_customer_timeline(
    customer_id: str,
    current_agent: dict = Depends(get_current_agent),
):
    """查客户时间线(关联的协作事件)"""
    data = get_customer_timeline(str(current_agent["_id"]), customer_id)
    return {"success": True, "data": data}

