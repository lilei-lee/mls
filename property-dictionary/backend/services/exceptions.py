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
