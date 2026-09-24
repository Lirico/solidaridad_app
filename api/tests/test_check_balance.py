from unittest.mock import MagicMock

import pytest

from application.payments.check_balance import CheckBalance
from application.payments.ports import BalanceResult, GatewayOutcome
from domain.exceptions import InvalidCardNumber, InvalidEntryMode, MissingTerminalId
from persistence.repositories.installation_repository import InstallationRepository


def _installation_repo() -> MagicMock:
    repo = MagicMock(spec=InstallationRepository)
    installation = MagicMock()
    installation.installation_id = "05000001"
    repo.get_by_installation_id.return_value = installation
    return repo


def _gateway(outcomes: dict[str, BalanceResult]) -> MagicMock:
    gateway = MagicMock()

    def balance(request: object) -> BalanceResult:
        return outcomes[request.product_code]  # type: ignore[attr-defined]

    gateway.balance.side_effect = balance
    return gateway


def _approved(minor: int) -> BalanceResult:
    return BalanceResult(
        outcome=GatewayOutcome.APPROVED,
        response_code="00",
        available_balance_minor=minor,
    )


def test_check_balance_returns_all_products() -> None:
    outcomes = {
        "993": _approved(10000),
        "994": _approved(20000),
        "995": _approved(30000),
        "996": _approved(40000),
        "997": _approved(50000),
    }
    uc = CheckBalance(_installation_repo(), _gateway(outcomes))
    result = uc.execute(installation_id="05000001", card_number="4111111111111111")
    assert result.status == "APPROVED"
    assert len(result.balances) == 5
    assert result.balances[0].product == "GARRAFA_10"
    assert result.balances[0].label == "Garrafa 10 kg"
    assert result.balances[0].available_balance_minor == 10000


def test_check_balance_product_without_saldo_is_zero() -> None:
    outcomes = {
        "993": _approved(10000),
        "994": BalanceResult(outcome=GatewayOutcome.DECLINED, response_code="06"),
        "995": _approved(30000),
        "996": _approved(40000),
        "997": _approved(50000),
    }
    uc = CheckBalance(_installation_repo(), _gateway(outcomes))
    result = uc.execute(installation_id="05000001", card_number="4111111111111111")
    assert result.status == "APPROVED"
    assert len(result.balances) == 5
    by_product = {b.product: b.available_balance_minor for b in result.balances}
    assert by_product["GARRAFA_15"] == 0


def test_check_balance_rejects_invalid_expiration() -> None:
    from domain.exceptions import InvalidExpirationDate

    gateway = MagicMock()
    uc = CheckBalance(_installation_repo(), gateway)
    with pytest.raises(InvalidExpirationDate):
        uc.execute(
            installation_id="05000001",
            card_number="4111111111111111",
            expiration_date="1325",
        )
    gateway.balance.assert_not_called()


def test_check_balance_card_invalid_returns_declined() -> None:
    outcomes = {
        code: BalanceResult(outcome=GatewayOutcome.DECLINED, response_code="14")
        for code in ("993", "994", "995", "996", "997")
    }
    uc = CheckBalance(_installation_repo(), _gateway(outcomes))
    result = uc.execute(installation_id="05000001", card_number="4111111111111111")
    assert result.status == "DECLINED"
    assert result.user_message == "Tarjeta inválida"
    assert result.balances == []


def test_check_balance_gateway_error_returns_failed() -> None:
    outcomes = {
        code: BalanceResult(outcome=GatewayOutcome.FAILED, response_code="96")
        for code in ("993", "994", "995", "996", "997")
    }
    uc = CheckBalance(_installation_repo(), _gateway(outcomes))
    result = uc.execute(installation_id="05000001", card_number="4111111111111111")
    assert result.status == "FAILED"
    assert result.balances == []


def test_check_balance_rejects_invalid_pan() -> None:
    uc = CheckBalance(_installation_repo(), _gateway({}))
    with pytest.raises(InvalidCardNumber):
        uc.execute(installation_id="05000001", card_number="606300101400740X")


def test_check_balance_rejects_invalid_entry_mode() -> None:
    uc = CheckBalance(_installation_repo(), _gateway({}))
    with pytest.raises(InvalidEntryMode):
        uc.execute(
            installation_id="05000001",
            card_number="4111111111111111",
            entry_mode="999",
        )


def test_check_balance_rejects_missing_terminal() -> None:
    repo = MagicMock(spec=InstallationRepository)
    repo.get_by_installation_id.return_value = None
    uc = CheckBalance(repo, _gateway({}))
    with pytest.raises(MissingTerminalId):
        uc.execute(installation_id="05000001", card_number="4111111111111111")
