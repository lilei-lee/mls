"""
照片上传 / 读取接口

POST /api/v1/photos        — 上传单张照片（需鉴权）
GET  /api/v1/photos/{key}  — 读取照片（需鉴权）
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from starlette.responses import StreamingResponse

from storage import upload_photo, get_photo, PhotoNotFound

# TODO(权限): 当前登录即可见照片；后续需按 listing 可见性细化
#  （带看申请审批通过后 BA 才可见原图），当前为登录即可见。

photos_router = APIRouter(prefix="/api/v1", tags=["photos"])

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png"}


def _get_current_agent_dep():
    """延迟导入 get_current_agent，避免循环依赖。

    photos_router 通过 Depends(_get_current_agent_dep) 间接引用 main 中定义的
    get_current_agent，两个模块不需要互相 import。
    """
    from main import get_current_agent
    return get_current_agent


@photos_router.post("/photos")
async def upload_photo_endpoint(
    file: UploadFile,
    current_agent: dict = Depends(_get_current_agent_dep),
):
    """上传单张照片。限制 ≤5MB，仅允许 JPEG/PNG。"""
    # 校验 content_type
    ct = file.content_type
    if ct not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"不支持的图片格式: {ct}，仅允许 image/jpeg 和 image/png",
        )

    # 读字节
    file_bytes = await file.read()

    # 校验大小
    if len(file_bytes) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"照片大小超过限制 ({MAX_FILE_SIZE // (1024*1024)}MB)",
        )

    # 上传
    key = upload_photo(file_bytes, ct)
    return {"photo_key": key, "url": f"/api/v1/photos/{key}"}


@photos_router.get("/photos/{key:path}")
async def get_photo_endpoint(
    key: str,
    current_agent: dict = Depends(_get_current_agent_dep),
):
    """读取照片，带鉴权。响应缓存 1 天。"""
    # TODO: 此处权限后续需按 listing 可见性(带看申请审批通过才可见)细化，
    # 当前为登录即可见。
    try:
        stream, content_type = get_photo(key)
    except PhotoNotFound:
        raise HTTPException(status_code=404, detail="照片不存在")

    return StreamingResponse(
        stream,
        media_type=content_type,
        headers={"Cache-Control": "private, max-age=86400"},
    )
