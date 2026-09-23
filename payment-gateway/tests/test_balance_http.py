from typing import Any
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from domain.authorization import AuthorizationStatus
from domain.balance import BalanceResult
from domain.exceptions import ProcessorUnavailable, ProcessorUnreachable
from infrastructure.iso.mock_processor import MockIsoProcessor
from main import app
from presentation.dependencies import get_check_balance, get_iso_processor

client = TestClient(app)


def _payload(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "product_code": "993",
        "card_number": "4111111111111111",
        "terminal_id": "TERM0001",
        "stan": "123456",
    }
    body.update(overrides)
    return body


def test_balance_http_approved_mock() -> None:
    app.dependency_overrides[get_iso_processor] = lambda: MockIsoProcessor()
    try:
        response = client.post("/v1/balance", json=_payload())
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "APPROVED"
        assert data["response_code"] == "00"
        assert data["available_balance_minor"] == 100000
    finally:
        app.dependency_overrides.clear()


def test_balance_http_declined_mock() -> None:
    app.dependency_overrides[get_iso_processor] = lambda: MockIsoProcessor()
    try:
        response = client.post(
            "/v1/balance",
            json=_payload(card_number="4000000000000002"),
        )
        assert response.status_code == 200
        assert response.json()["status"] == "DECLINED"
    finally:
        app.dependency_overrides.clear()


def test_balance_http_invalid_pan() -> None:
    response = client.post(
        "/v1/balance",
        json=_payload(card_number="606300101400740X"),
    )
    assert response.status_code == 400
    assert "message" in response.json()


def test_balance_http_processor_unavailable() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = ProcessorUnavailable()
    app.dependency_overrides[get_check_balance] = lambda: use_case
    try:
        response = client.post("/v1/balance", json=_payload())
        assert response.status_code == 502
    finally:
        app.dependency_overrides.clear()


def test_balance_http_processor_unreachable() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = ProcessorUnreachable()
    app.dependency_overrides[get_check_balance] = lambda: use_case
    try:
        response = client.post("/v1/balance", json=_payload())
        assert response.status_code == 503
    finally:
        app.dependency_overrides.clear()


def test_balance_http_with_processor_override() -> None:
    class FixedProcessor:
        def authorize(self, command: object) -> object:
            raise AssertionError("authorize should not be called")

        def void(self, command: object) -> object:
            raise AssertionError("void should not be called")

        def balance(self, command: object) -> BalanceResult:
            return BalanceResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="Aprobada",
                available_balance_minor=1250,
                assigned_products="Tipo de asignacion: Granel",
            )

    app.dependency_overrides[get_iso_processor] = lambda: FixedProcessor()
    try:
        response = client.post("/v1/balance", json=_payload(product_code="997"))
        assert response.status_code == 200
        assert response.json()["available_balance_minor"] == 1250
    finally:
        app.dependency_overrides.clear()
