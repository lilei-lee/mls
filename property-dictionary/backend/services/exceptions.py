"""辞典系统内部异常类型"""

class DictionaryError(Exception):
    """辞典系统基础异常"""
    pass

class CityNotFound(DictionaryError):
    pass

class DistrictNotFound(DictionaryError):
    pass

class CommunityNotFound(DictionaryError):
    pass

class PropertyNotFound(DictionaryError):
    pass

class InvalidIdentifier(DictionaryError):
    pass

class InvalidClaimField(DictionaryError):
    """claim 字段不在白名单"""
    pass

class InvalidClaimValue(DictionaryError):
    """claim 值类型不匹配字段要求"""
    pass

class DiscrepancyNotFound(DictionaryError):
    """discrepancy 工单不存在"""
    pass

class DiscrepancyAlreadyReviewed(DictionaryError):
    """discrepancy 已复核,不能重复"""
    pass
