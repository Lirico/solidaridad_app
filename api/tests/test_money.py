import pytest

from domain.exceptions import InvalidAmount
from domain.money import parse_amount


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
