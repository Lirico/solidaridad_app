from unittest.mock import MagicMock

import pytest

from application.payments.reverse_payment import ReversePayment
from domain.exceptions import (
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    InvalidTicket,
    UnsupportedProduct,
)
from domain.reversal import ReversalResult, ReversalStatus, ReverseCommand


def _command(**overrides: object) -> ReverseCommand:
    values: dict[str, object] = {
        "product_code": "993",
        "amount_minor": 150050,
        "card_number": "4111111111111111",
        "expiration_date": "3012",
        "terminal_id": "TERM0001",
        "original_stan": "123456",
        "original_ticket": "00000042",
        "reversal_stan": "654321",
    }
    values.update(overrides)
    return ReverseCommand(**values)  # type: ignore[arg-type]


def test_reverse_normalizes_and_executes_once() -> None:
    processor = MagicMock()
    processor.reverse.return_value = ReversalResult(
        status=ReversalStatus.REVERSED_CONFIRMED,
        response_code="00",
        user_message="Reverso aceptado",
    )

    result = ReversePayment(processor).execute(
        _command(
            terminal_id=" T1 ",
            original_stan="7",
            original_ticket="ticket-42",
            reversal_stan="8",
        )
    )

    assert result.status == ReversalStatus.REVERSED_CONFIRMED
    processor.reverse.assert_called_once_with(
        ReverseCommand(
            product_code="993",
            amount_minor=150050,
            card_number="4111111111111111",
            expiration_date="3012",
            terminal_id="T1      ",
            original_stan="000007",
            original_ticket="42",
            reversal_stan="000008",
        )
    )


@pytest.mark.parametrize(
    ("overrides", "error"),
    [
        ({"amount_minor": 0}, InvalidAmount),
        ({"amount_minor": 1_000_000_000_000}, InvalidAmount),
        ({"card_number": "4111X"}, InvalidCardNumber),
        ({"expiration_date": "30XX"}, InvalidCardNumber),
        ({"terminal_id": "  "}, InvalidTerminalId),
        ({"original_stan": "ABC"}, InvalidStan),
        ({"reversal_stan": "1234567"}, InvalidStan),
        ({"original_ticket": "ABC"}, InvalidTicket),
        ({"product_code": "998"}, UnsupportedProduct),
    ],
)
def test_reverse_rejects_invalid_commands(
    overrides: dict[str, object], error: type[Exception]
) -> None:
    processor = MagicMock()

    with pytest.raises(error):
        ReversePayment(processor).execute(_command(**overrides))

    processor.reverse.assert_not_called()
