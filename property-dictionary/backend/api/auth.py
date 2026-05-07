"""API Key 鉴权 dependency"""
from fastapi import Header, HTTPException, status
from typing import Optional, Annotated
from config import DICT_API_KEYS


def require_api_key(
    x_api_key: Annotated[Optional[str], Header(description="API Key")] = None,
) -> dict:
    if not x_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-API-Key header")
    key_meta = DICT_API_KEYS.get(x_api_key)
    if not key_meta:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid API Key")
    if not key_meta.get("active", True):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="API Key inactive")
    return {
        "owner": key_meta["owner"],
        "permissions": key_meta["permissions"],
        "city_scope": key_meta["city_scope"],
        "_key_prefix": x_api_key[:8] + "..." if len(x_api_key) > 8 else x_api_key,
    }


def check_city_scope(api_key_meta: dict, city_id: str) -> None:
    scope = api_key_meta.get("city_scope", "all")
    if scope == "all":
        return
    if isinstance(scope, list):
        scope_strs = [str(c) for c in scope]
        if str(city_id) not in scope_strs:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"API Key (owner={api_key_meta.get('owner')}) not authorized for city {city_id}",
            )
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=f"API Key has invalid city_scope: {scope!r}",
    )
