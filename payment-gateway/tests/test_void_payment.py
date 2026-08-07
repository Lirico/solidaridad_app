from application.payments.void_payment import VoidPayment
from domain.authorization import AuthorizationResult, AuthorizationStatus, VoidCommand
from domain.exceptions import (
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    InvalidTicket,
    UnsupportedProduct,
)
from infrastructure.iso.mock_processor import MockIsoProcessor


def _cmd(**overrides: object) -> VoidCommand:
    base: dict[str, object] = {
        "product_code": "993",
        "amount_minor": 150050,
        "card_number": "4111111111111111",
        "terminal_id": "TERM0001",
        "stan": "654321",
        "original_ticket": "00000042",
        "void_ticket": "654321",
    }
    base.update(overrides)
    return VoidCommand(**base)  # type: ignore[arg-type]


def test_void_approves_with_mock() -> None:
    uc = VoidPayment(MockIsoProcessor())
    result = uc.execute(_cmd())
    assert result.status == AuthorizationStatus.APPROVED
    assert result.auth_id == "MOCKVD"


def test_void_declines_known_pan() -> None:
    uc = VoidPayment(MockIsoProcessor())
    result = uc.execute(_cmd(card_number="4000000000000002"))
    assert result.status == AuthorizationStatus.DECLINED


def test_void_rejects_invalid_amount() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(amount_minor=0))
        raise AssertionError("expected InvalidAmount")
    except InvalidAmount:
        pass


def test_void_rejects_bad_pan() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(card_number="606300101400740X"))
        raise AssertionError("expected InvalidCardNumber")
    except InvalidCardNumber:
        pass


def test_void_rejects_unsupported_product() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(product_code="998"))
        raise AssertionError("expected UnsupportedProduct")
    except UnsupportedProduct:
        pass


def test_void_rejects_empty_terminal() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(terminal_id="   "))
        raise AssertionError("expected InvalidTerminalId")
    except InvalidTerminalId:
        pass


def test_void_rejects_bad_stan() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(stan="abcdef"))
        raise AssertionError("expected InvalidStan")
    except InvalidStan:
        pass


def test_void_rejects_empty_original_ticket() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(original_ticket="abc"))
        raise AssertionError("expected InvalidTicket")
    except InvalidTicket:
        pass


def test_void_rejects_empty_void_ticket() -> None:
    uc = VoidPayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(void_ticket="abc"))
        raise AssertionError("expected InvalidTicket")
    except InvalidTicket:
        pass


def test_void_normalizes_fields() -> None:
    class CapturingProcessor:
        last: VoidCommand | None = None

        def authorize(self, command: object) -> AuthorizationResult:
            raise AssertionError("authorize should not be called")

        def void(self, command: VoidCommand) -> AuthorizationResult:
            self.last = command
            return AuthorizationResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="ok",
            )

    processor = CapturingProcessor()
    uc = VoidPayment(processor)
    uc.execute(_cmd(stan="7", terminal_id="T1"))
    assert processor.last is not None
    assert processor.last.stan == "000007"
    assert processor.last.terminal_id == "T1      "
    assert processor.last.original_ticket == "00000042"
