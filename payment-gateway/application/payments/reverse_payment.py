"""Reverse an indeterminate purchase via the ISO processor port."""

from application.payments.ports import IsoProcessor
from domain.amount import AMOUNT_TOO_LARGE, MAX_AMOUNT_MINOR
from domain.exceptions import (
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    InvalidTicket,
)
from domain.product import product_code_de49
from domain.reversal import ReversalResult, ReverseCommand


class ReversePayment:
    def __init__(self, processor: IsoProcessor) -> None:
        self._processor = processor

    def execute(self, command: ReverseCommand) -> ReversalResult:
        if command.amount_minor <= 0:
            raise InvalidAmount()
        if command.amount_minor > MAX_AMOUNT_MINOR:
            raise InvalidAmount(AMOUNT_TOO_LARGE)

        pan = command.card_number.strip()
        if not pan.isdigit() or not (13 <= len(pan) <= 19):
            raise InvalidCardNumber()
        product_code_de49(command.product_code)

        terminal_id = command.terminal_id.strip()
        if not terminal_id:
            raise InvalidTerminalId()

        original_stan = command.original_stan.strip()
        if not original_stan.isdigit() or len(original_stan) > 6:
            raise InvalidStan("original_stan inválido")
        reversal_stan = command.reversal_stan.strip()
        if not reversal_stan.isdigit() or len(reversal_stan) > 6:
            raise InvalidStan("reversal_stan inválido")

        original_ticket = "".join(
            character
            for character in command.original_ticket.strip()
            if character.isdigit()
        )
        if not original_ticket:
            raise InvalidTicket("original_ticket inválido")

        expiration_date = command.expiration_date.strip()
        if not expiration_date.isdigit() or len(expiration_date) != 4:
            raise InvalidCardNumber("Fecha de vencimiento inválida")

        normalized = ReverseCommand(
            product_code=command.product_code,
            amount_minor=command.amount_minor,
            card_number=pan,
            expiration_date=expiration_date,
            terminal_id=terminal_id[:8].ljust(8),
            original_stan=original_stan.zfill(6),
            original_ticket=original_ticket,
            reversal_stan=reversal_stan.zfill(6),
        )
        return self._processor.reverse(normalized)
