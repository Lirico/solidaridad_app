"""Consultar saldo (0100) via the ISO processor port."""

from application.payments.ports import IsoProcessor
from domain.balance import BalanceCommand, BalanceResult
from domain.exceptions import (
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
)
from domain.product import product_code_de49


class CheckBalance:
    def __init__(self, processor: IsoProcessor) -> None:
        self._processor = processor

    def execute(self, command: BalanceCommand) -> BalanceResult:
        pan = command.card_number.strip()
        if not pan.isdigit() or not (13 <= len(pan) <= 19):
            raise InvalidCardNumber()
        product_code_de49(command.product_code)
        if not command.terminal_id.strip():
            raise InvalidTerminalId()
        stan = command.stan.strip()
        if not stan.isdigit() or len(stan) > 6:
            raise InvalidStan()

        normalized = BalanceCommand(
            product_code=command.product_code,
            card_number=pan,
            terminal_id=command.terminal_id.strip()[:8].ljust(8),
            stan=stan.zfill(6),
            expiration_date=command.expiration_date,
            entry_mode=command.entry_mode,
            track2=command.track2,
        )
        return self._processor.balance(normalized)
