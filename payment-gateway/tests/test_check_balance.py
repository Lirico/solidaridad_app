from application.payments.check_balance import CheckBalance
from domain.authorization import AuthorizationStatus
from domain.balance import BalanceCommand, BalanceResult
from domain.exceptions import (
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    UnsupportedProduct,
)
from infrastructure.iso.mock_processor import MockIsoProcessor


def _cmd(**overrides: object) -> BalanceCommand:
    base: dict[str, object] = {
        "product_code": "993",
        "card_number": "4111111111111111",
        "terminal_id": "TERM0001",
        "stan": "123456",
    }
    base.update(overrides)
    return BalanceCommand(**base)  # type: ignore[arg-type]


def test_balance_approves_with_mock() -> None:
    uc = CheckBalance(MockIsoProcessor())
    result = uc.execute(_cmd())
    assert result.status == AuthorizationStatus.APPROVED
    assert result.available_balance_minor == 100000
    assert result.assigned_products is not None


def test_balance_declines_known_pan() -> None:
    uc = CheckBalance(MockIsoProcessor())
    result = uc.execute(_cmd(card_number="4000000000000002"))
    assert result.status == AuthorizationStatus.DECLINED


def test_balance_rejects_bad_pan() -> None:
    uc = CheckBalance(MockIsoProcessor())
    try:
        uc.execute(_cmd(card_number="606300101400740X"))
        raise AssertionError("expected InvalidCardNumber")
    except InvalidCardNumber:
        pass


def test_balance_rejects_unsupported_product() -> None:
    uc = CheckBalance(MockIsoProcessor())
    try:
        uc.execute(_cmd(product_code="998"))
        raise AssertionError("expected UnsupportedProduct")
    except UnsupportedProduct:
        pass


def test_balance_rejects_empty_terminal() -> None:
    uc = CheckBalance(MockIsoProcessor())
    try:
        uc.execute(_cmd(terminal_id="   "))
        raise AssertionError("expected InvalidTerminalId")
    except InvalidTerminalId:
        pass


def test_balance_rejects_bad_stan() -> None:
    uc = CheckBalance(MockIsoProcessor())
    try:
        uc.execute(_cmd(stan="abcdef"))
        raise AssertionError("expected InvalidStan")
    except InvalidStan:
        pass


def test_balance_normalizes_stan_and_terminal() -> None:
    class CapturingProcessor:
        last: BalanceCommand | None = None

        def authorize(self, command: object) -> object:
            raise AssertionError("authorize should not be called")

        def void(self, command: object) -> object:
            raise AssertionError("void should not be called")

        def balance(self, command: BalanceCommand) -> BalanceResult:
            self.last = command
            return BalanceResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="ok",
            )

    processor = CapturingProcessor()
    uc = CheckBalance(processor)
    uc.execute(_cmd(stan="42", terminal_id="T1"))
    assert processor.last is not None
    assert processor.last.stan == "000042"
    assert processor.last.terminal_id == "T1      "
