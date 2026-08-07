from typing import Any
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from domain.authorization import (
    AuthorizationResult,
    AuthorizationStatus,
    AuthorizeCommand,
)
from domain.exceptions import ProcessorUnavailable
from infrastructure.iso.mock_processor import MockIsoProcessor
from main import app
from presentation.dependencies import get_authorize_payment, get_iso_processor

client = TestClient(app)


def _payload(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "product_code": "993",
        "amount_minor": 150050,
        "card_number": "4111111111111111",
        "terminal_id": "TERM0001",
        "stan": "123456",
        "transaction_number": "OP-260716-0001",
    }

    body.update(overrides)
    return body


def test_authorize_http_approved_mock() -> None:
    # Force the mock processor so the test is deterministic regardless of
    # local .env (ISO_TRANSPORT may point to a real TCP processor).
    app.dependency_overrides[get_iso_processor] = lambda: MockIsoProcessor()
    try:
        response = client.post("/v1/authorize", json=_payload())
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "APPROVED"
        assert data["response_code"] == "00"
    finally:
        app.dependency_overrides.clear()


def test_authorize_http_declined_mock() -> None:
    # Force the mock processor so the test is deterministic regardless of
    # local .env (ISO_TRANSPORT may point to a real TCP processor).
    app.dependency_overrides[get_iso_processor] = lambda: MockIsoProcessor()
    try:
        response = client.post(
            "/v1/authorize",
            json=_payload(card_number="4000000000000002"),
        )
        assert response.status_code == 200
        assert response.json()["status"] == "DECLINED"
    finally:
        app.dependency_overrides.clear()


def test_authorize_http_invalid_pan() -> None:
    response = client.post(
        "/v1/authorize",
        json=_payload(card_number="4111111111111112"),
    )
    assert response.status_code == 400
    assert "message" in response.json()


def test_authorize_http_validation_error() -> None:
    response = client.post("/v1/authorize", json=_payload(amount_minor=0))
    assert response.status_code == 400
    assert "message" in response.json()


def test_authorize_http_processor_unavailable() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = ProcessorUnavailable()
    app.dependency_overrides[get_authorize_payment] = lambda: use_case
    try:
        response = client.post("/v1/authorize", json=_payload())
        assert response.status_code == 502
        assert response.json()["message"] == "Procesador de pagos no disponible"
    finally:
        app.dependency_overrides.clear()


def test_authorize_http_generic_domain_error() -> None:
    from domain.exceptions import IsoPackError

    use_case = MagicMock()
    use_case.execute.side_effect = IsoPackError("boom")
    app.dependency_overrides[get_authorize_payment] = lambda: use_case
    try:
        response = client.post("/v1/authorize", json=_payload())
        assert response.status_code == 400
        assert response.json()["message"] == "boom"
    finally:
        app.dependency_overrides.clear()


def test_authorize_http_with_processor_override() -> None:
    class FixedProcessor:
        def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
            assert command.product_code == "994"
            return AuthorizationResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="Aprobada",
                auth_id="FIX001",
                retrieval_reference="RRN",
            )


    app.dependency_overrides[get_iso_processor] = lambda: FixedProcessor()
    try:
        response = client.post("/v1/authorize", json=_payload(product_code="994"))
        assert response.status_code == 200
        assert response.json()["auth_id"] == "FIX001"
    finally:
        app.dependency_overrides.clear()
