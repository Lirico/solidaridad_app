"""Quantity in minor units (exponent 2)."""

from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

from domain.exceptions import InvalidAmount

AMOUNT_EXPONENT = 2
# DE4 is 12 BCD digits with 2 implied decimals (9_999_999_999.99).
MAX_AMOUNT_MINOR = 999_999_999_999
MAX_AMOUNT_TEXT = "9999999999.99"


@dataclass(frozen=True, slots=True)
class Money:
    amount_minor: int

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise InvalidAmount()


def parse_amount(value: str) -> Money:
    text = value.strip()
    try:
        amount = Decimal(text)
    except InvalidOperation as exc:
        raise InvalidAmount() from exc

    if amount <= 0 or amount != amount.quantize(Decimal(10) ** -AMOUNT_EXPONENT):
        raise InvalidAmount()

    amount_minor = int(amount * (10**AMOUNT_EXPONENT))
    if amount_minor <= 0:
        raise InvalidAmount()
    if amount_minor > MAX_AMOUNT_MINOR:
        raise InvalidAmount("La cantidad supera el máximo permitido")
    return Money(amount_minor=amount_minor)
