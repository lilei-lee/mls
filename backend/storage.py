"""
MinIO 对象存储服务 — 照片上传 / 读取

用法:
    from storage import upload_photo, get_photo, ensure_bucket
    key = upload_photo(file_bytes, "image/jpeg")
    stream, ct = get_photo(key)
"""
import io
import uuid
import logging
from datetime import datetime

from minio import Minio
from minio.error import S3Error

from config import MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_BUCKET, MINIO_SECURE

logger = logging.getLogger("mls.storage")

# 模块级 MinIO 客户端（项目级复用）
_client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=MINIO_SECURE,
)

# content_type → 文件扩展名
_CONTENT_TYPE_TO_EXT = {
    "image/jpeg": "jpg",
    "image/png": "png",
}


class PhotoNotFound(Exception):
    """照片不存在时抛出。"""
    def __init__(self, key: str):
        super().__init__(f"照片不存在: {key}")
        self.key = key


def ensure_bucket() -> None:
    """确保 MINIO_BUCKET 存在，不存在则创建。

    开发期 MinIO 可能未启动，失败时只打 warning 不阻止启动。
    """
    try:
        if not _client.bucket_exists(MINIO_BUCKET):
            _client.make_bucket(MINIO_BUCKET)
            logger.info("[storage] Created bucket: %s", MINIO_BUCKET)
        else:
            logger.info("[storage] Bucket exists: %s", MINIO_BUCKET)
    except Exception as e:
        logger.warning("[storage] ensure_bucket failed (MinIO may be down): %s", e)


def upload_photo(file_bytes: bytes, content_type: str) -> str:
    """上传照片到 MinIO，返回 object key。

    key 格式: photos/{yyyy}/{mm}/{uuid}.{ext}
    """
    ext = _CONTENT_TYPE_TO_EXT.get(content_type, "jpg")
    now = datetime.utcnow()
    key = f"photos/{now.year:04d}/{now.month:02d}/{uuid.uuid4().hex}.{ext}"

    data = io.BytesIO(file_bytes)
    length = len(file_bytes)

    _client.put_object(
        MINIO_BUCKET,
        key,
        data,
        length,
        content_type=content_type,
    )
    return key


def get_photo(key: str) -> tuple:
    """读取照片，返回 (字节流可迭代对象, content_type)。

    对象不存在时抛 PhotoNotFound。
    """
    try:
        stat = _client.stat_object(MINIO_BUCKET, key)
        response = _client.get_object(MINIO_BUCKET, key)
        return response, stat.content_type or "image/jpeg"
    except S3Error as e:
        if e.code == "NoSuchKey":
            raise PhotoNotFound(key) from e
        raise
