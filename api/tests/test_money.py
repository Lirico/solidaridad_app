import pytest

from domain.exceptions import InvalidAmount
from domain.money import MAX_AMOUNT_MINOR, parse_amount


def test_parse_amount_ok() -> None:
    money = parse_amount("1.50")
    assert money.amount_minor == 150


def test_parse_amount_rejects_float_scale() -> None:
    with pytest.raises(InvalidAmount):
        parse_amount("1.555")


def test_parse_amount_rejects_zero() -> None:
    with pytest.raises(InvalidAmount):
        parse_amount("0")


def test_parse_amount_rejects_garbage() -> None:
    with pytest.raises(InvalidAmount):
        parse_amount("abc")


def test_parse_amount_accepts_de4_maximum() -> None:
    money = parse_amount("9999999999.99")
    assert money.amount_minor == MAX_AMOUNT_MINOR


def test_parse_amount_rejects_above_de4() -> None:
    with pytest.raises(InvalidAmount, match="máximo permitido"):
        parse_amount("10000000000.00")
