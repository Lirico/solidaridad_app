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
    UnsupportedProduct,
)
from infrastructure.iso.mock_processor import MockIsoProcessor


def _cmd(**overrides: object) -> AuthorizeCommand:
    base: dict[str, object] = {
        "product_code": "993",
        "amount_minor": 150050,
        "card_number": "4111111111111111",
        "terminal_id": "TERM0001",
        "stan": "123456",
        "ticket_number": "00000042",
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
        uc.execute(_cmd(card_number="606300101400740X"))
        raise AssertionError("expected InvalidCardNumber")
    except InvalidCardNumber:
        pass


def test_authorize_accepts_processor_pan_without_luhn() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    result = uc.execute(_cmd(card_number="6063001014007403"))
    assert result.status == AuthorizationStatus.APPROVED


def test_authorize_rejects_unsupported_product() -> None:
    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(product_code="998"))
        raise AssertionError("expected UnsupportedProduct")
    except UnsupportedProduct:
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


def test_authorize_rejects_empty_ticket() -> None:
    from domain.exceptions import InvalidTicket

    uc = AuthorizePayment(MockIsoProcessor())
    try:
        uc.execute(_cmd(ticket_number="abc"))
        raise AssertionError("expected InvalidTicket")
    except InvalidTicket:
        pass


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

        def void(self, command: object) -> AuthorizationResult:
            raise AssertionError("void should not be called")

    processor = CapturingProcessor()
    uc = AuthorizePayment(processor)
    uc.execute(_cmd(stan="42", terminal_id="T1"))
    assert processor.last is not None
    assert processor.last.stan == "000042"
    assert processor.last.terminal_id == "T1      "
    assert processor.last.ticket_number == "00000042"


def test_authorize_propagates_valid_cvv() -> None:
    """El CVV válido se normaliza y viaja en el comando al procesador."""
    class CapturingProcessor:
        last: AuthorizeCommand | None = None

        def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
            self.last = command
            return AuthorizationResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="ok",
            )

        def void(self, command: object) -> AuthorizationResult:
            raise AssertionError("void should not be called")

    processor = CapturingProcessor()
    uc = AuthorizePayment(processor)
    uc.execute(_cmd(cvv="878"))
    assert processor.last is not None
    assert processor.last.cvv == "878"


def test_authorize_allows_missing_cvv() -> None:
    """Banda (022) / manual sin CVV: cvv es None y no se valida."""
    uc = AuthorizePayment(MockIsoProcessor())
    result = uc.execute(_cmd(entry_mode="022"))
    assert result.status == AuthorizationStatus.APPROVED


def test_authorize_rejects_bad_cvv() -> None:
    """CVV no numérico o de longitud inválida se rechaza."""
    from domain.exceptions import InvalidCvv

    uc = AuthorizePayment(MockIsoProcessor())
    for bad in ("abc", "12", "12345"):
        try:
            uc.execute(_cmd(cvv=bad))
            raise AssertionError(f"expected InvalidCvv for cvv={bad!r}")
        except InvalidCvv:
            pass
