"""Void (anulación) a purchase via the ISO processor port."""

from application.payments.ports import IsoProcessor
from domain.authorization import AuthorizationResult, VoidCommand
from domain.exceptions import (
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    InvalidTicket,
)
from domain.product import product_code_de49


class VoidPayment:
    def __init__(self, processor: IsoProcessor) -> None:
        self._processor = processor

    def execute(self, command: VoidCommand) -> AuthorizationResult:
        if command.amount_minor <= 0:
            raise InvalidAmount()
        pan = command.card_number.strip()
        if not pan.isdigit() or not (13 <= len(pan) <= 19):
            raise InvalidCardNumber()
        product_code_de49(command.product_code)
        if not command.terminal_id.strip():
            raise InvalidTerminalId()
        stan = command.stan.strip()
        if not stan.isdigit() or len(stan) > 6:
            raise InvalidStan()
        original = "".join(c for c in command.original_ticket.strip() if c.isdigit())
        if not original:
            raise InvalidTicket()
        void_ticket = "".join(c for c in command.void_ticket.strip() if c.isdigit())
        if not void_ticket:
            raise InvalidTicket("ticket de anulación inválido")

        normalized = VoidCommand(
            product_code=command.product_code,
            amount_minor=command.amount_minor,
            card_number=pan,
            terminal_id=command.terminal_id.strip()[:8].ljust(8),
            stan=stan.zfill(6),
            original_ticket=original,
            void_ticket=void_ticket,
            expiration_date=command.expiration_date,
        )
        return self._processor.void(normalized)
