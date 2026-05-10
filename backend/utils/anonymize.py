"""姓名脱敏工具 — 姓+* 如"李红"→"李*" """

def anonymize_name(full_name: str) -> str:
    if not full_name:
        return "匿*"
    if len(full_name) == 1:
        return full_name[0] + "*"
    return full_name[0] + "*"
