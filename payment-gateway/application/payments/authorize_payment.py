"""Authorize a purchase via the ISO processor port."""

from application.payments.ports import IsoProcessor
from domain.authorization import AuthorizationResult, AuthorizeCommand
from domain.exceptions import (
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
)
from domain.product import product_code_de49


def _luhn_ok(pan: str) -> bool:
    digits = [int(c) for c in pan]
    checksum = 0
    parity = len(digits) % 2
    for i, d in enumerate(digits):
        if i % 2 == parity:
            d *= 2
            if d > 9:
                d -= 9
        checksum += d
    return checksum % 10 == 0


class AuthorizePayment:
    def __init__(self, processor: IsoProcessor) -> None:
        self._processor = processor

    def execute(self, command: AuthorizeCommand) -> AuthorizationResult:
        if command.amount_minor <= 0:
            raise InvalidAmount()
        pan = command.card_number.strip()
        if not pan.isdigit() or not (13 <= len(pan) <= 19) or not _luhn_ok(pan):
            raise InvalidCardNumber()
        product_code_de49(command.product_code)
        if not command.terminal_id.strip():
            raise InvalidTerminalId()
        stan = command.stan.strip()
        if not stan.isdigit() or len(stan) > 6:
            raise InvalidStan()

        normalized = AuthorizeCommand(
            product_code=command.product_code,
            amount_minor=command.amount_minor,
            card_number=pan,
            terminal_id=command.terminal_id.strip()[:8].ljust(8),
            stan=stan.zfill(6),
            transaction_number=command.transaction_number,
            expiration_date=command.expiration_date,
        )

        return self._processor.authorize(normalized)
