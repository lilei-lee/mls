import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId
from services.coding import generate_property_code, verify_property_code

CITY = ObjectId("000000000000000000000001")
DISTRICT = ObjectId("000000000000000000000002")
COMMUNITY = ObjectId("000000000000000000000003")


def test_deterministic():
    code1 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    code2 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    assert code1 == code2


def test_different_inputs_different_codes():
    code1 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    code2 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "503")
    assert code1 != code2


def test_different_community_different_codes():
    other = ObjectId("000000000000000000000099")
    code1 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    code2 = generate_property_code(CITY, DISTRICT, other, "3", "1", "502")
    assert code1 != code2


def test_objectid_and_string_equivalent():
    code1 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    code2 = generate_property_code(
        str(CITY), str(DISTRICT), str(COMMUNITY), "3", "1", "502"
    )
    assert code1 == code2


def test_whitespace_stripped():
    code1 = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    code2 = generate_property_code(CITY, DISTRICT, COMMUNITY, " 3 ", " 1 ", " 502 ")
    assert code1 == code2


def test_code_format():
    code = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    assert len(code) == 12
    valid_chars = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    assert all(c in valid_chars for c in code)


def test_verify_correct():
    code = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    assert verify_property_code(code, CITY, DISTRICT, COMMUNITY, "3", "1", "502")


def test_verify_wrong():
    code = generate_property_code(CITY, DISTRICT, COMMUNITY, "3", "1", "502")
    assert not verify_property_code(code, CITY, DISTRICT, COMMUNITY, "3", "1", "503")
