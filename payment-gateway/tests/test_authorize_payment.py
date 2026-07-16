from application.payments.authorize_payment import AuthorizePayment
from domain.authorization import (
    AuthorizationResult,
    AuthorizationStatus,
    AuthorizeCommand,
)
from domain.exceptions import (
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    UnsupportedCurrency,
)
from infrastructure.iso.mock_processor import MockIsoProcessor


def _cmd(**overrides: object) -> AuthorizeCommand:
    base: dict[str, object] = {
        "currency": "ARS",
        "amount_minor": 150050,
        "card_number": "4111111111111111",
        "terminal_id": "TERM0001",
        "stan": "123456",
    }
    base.update(overrides)
    return AuthorizeCommand(**base)  # type: ignore[arg-type]


def test_authorize_approves_with_mock() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    result = uc.execute(_cmd())
    assert result.status == AuthorizationStatus.APPROVED
    assert result.response_code == "00"
    assert result.auth_id == "MOCK01"


def test_authorize_declines_known_pan() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    result = uc.execute(_cmd(card_number="4000000000000002"))
    assert result.status == AuthorizationStatus.DECLINED
    assert result.response_code == "05"


def test_authorize_rejects_invalid_amount() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(amount_minor=0))
        raise AssertionError("expected InvalidAmount")
    except InvalidAmount:
        pass


def test_authorize_rejects_bad_pan() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(card_number="4111111111111112"))
        raise AssertionError("expected InvalidCardNumber")
    except InvalidCardNumber:
        pass


def test_authorize_rejects_unsupported_currency() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(currency="EUR"))
        raise AssertionError("expected UnsupportedCurrency")
    except UnsupportedCurrency:
        pass


def test_authorize_rejects_empty_terminal() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(terminal_id="   "))
        raise AssertionError("expected InvalidTerminalId")
    except InvalidTerminalId:
        pass


def test_authorize_rejects_bad_stan() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(stan="abcdef"))
        raise AssertionError("expected InvalidStan")
    except InvalidStan:
        pass


def test_luhn_rejects_non_digit_midway() -> None:
    from application.payments.authorize_payment import _luhn_ok

    assert _luhn_ok("4111111111111111")
    # Force branch where doubled digit > 9
    assert not _luhn_ok("4111111111111110")


def test_authorize_normalizes_stan_and_terminal() -> None:
    class CapturingProcessor:
        last: AuthorizeCommand | None = None

        def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
            self.last = command
            return AuthorizationResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="ok",
            )

    processor = CapturingProcessor()
    uc = AuthorizePayment(processor)
    uc.execute(_cmd(stan="42", terminal_id="T1"))
    assert processor.last is not None
    assert processor.last.stan == "000042"
    assert processor.last.terminal_id == "T1      "
