"""Balance inquiry HTTP controller tests."""

from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.payments.check_balance import BalanceItem, CheckBalanceResult
from domain.exceptions import InvalidCardNumber, MissingTerminalId
from main import app
from presentation.dependencies import CurrentUser, get_check_balance, get_current_user

client = TestClient(app)


def _payload(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {"card_number": "4111111111111111"}
    body.update(overrides)
    return body


def _current_user() -> CurrentUser:
    return CurrentUser(user_id=1, email="a@b.c", installation_id="05000001")


def test_balance_http_ok() -> None:
    use_case = MagicMock()
    use_case.execute.return_value = CheckBalanceResult(
        status="APPROVED",
        user_message="Consulta de saldo exitosa",
        balances=[
            BalanceItem(
                product="GARRAFA_10",
                label="Garrafa 10 kg",
                available_balance_minor=10000,
            ),
            BalanceItem(
                product="GARRAFA_15",
                label="Garrafa 15 kg",
                available_balance_minor=0,
            ),
        ],
    )
    app.dependency_overrides[get_current_user] = _current_user
    app.dependency_overrides[get_check_balance] = lambda: use_case
    try:
        response = client.post("/v1/balance", json=_payload())
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "APPROVED"
        assert data["balances"][0]["product"] == "GARRAFA_10"
        assert data["balances"][0]["available_balance"] == "100"
        assert data["balances"][1]["available_balance"] == "0"
    finally:
        app.dependency_overrides.clear()


def test_balance_http_invalid_pan() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = InvalidCardNumber()
    app.dependency_overrides[get_current_user] = _current_user
    app.dependency_overrides[get_check_balance] = lambda: use_case
    try:
        response = client.post(
            "/v1/balance",
            json=_payload(card_number="606300101400740X"),
        )
        assert response.status_code == 400
        assert "message" in response.json()
    finally:
        app.dependency_overrides.clear()


def test_balance_http_missing_terminal() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = MissingTerminalId()
    app.dependency_overrides[get_current_user] = _current_user
    app.dependency_overrides[get_check_balance] = lambda: use_case
    try:
        response = client.post("/v1/balance", json=_payload())
        assert response.status_code == 400
    finally:
        app.dependency_overrides.clear()
