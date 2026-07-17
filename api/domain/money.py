"""Quantity in minor units (exponent 2)."""

from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

from domain.exceptions import InvalidAmount
from domain.product import AMOUNT_EXPONENT


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
    return Money(amount_minor=amount_minor)
