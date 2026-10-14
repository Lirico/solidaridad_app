from typing import Any
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from domain.exceptions import ProcessorUnavailable, ProcessorUnreachable
from domain.reversal import ReversalResult, ReversalStatus
from infrastructure.iso.mock_processor import MockIsoProcessor
from main import app
from presentation.dependencies import get_iso_processor, get_reverse_payment

client = TestClient(app)


def _payload(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "product_code": "993",
        "amount_minor": 150050,
        "card_number": "4111111111111111",
        "expiration_date": "3012",
        "terminal_id": "TERM0001",
        "original_stan": "123456",
        "original_ticket": "00000042",
        "reversal_stan": "654321",
    }
    body.update(overrides)
    return body


def test_reverse_http_confirmed() -> None:
    app.dependency_overrides[get_iso_processor] = lambda: MockIsoProcessor()
    try:
        response = client.post("/v1/reverse", json=_payload())
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {
        "status": "REVERSED_CONFIRMED",
        "response_code": "00",
        "user_message": "Reverso aceptado",
    }


def test_reverse_http_processor_declined() -> None:
    app.dependency_overrides[get_iso_processor] = lambda: MockIsoProcessor()
    try:
        response = client.post(
            "/v1/reverse",
            json=_payload(card_number="4000000000000002"),
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["status"] == "PROCESSOR_DECLINED"


def test_reverse_http_not_sent_is_retryable() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = ProcessorUnreachable()
    app.dependency_overrides[get_reverse_payment] = lambda: use_case
    try:
        response = client.post("/v1/reverse", json=_payload())
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 503
    assert response.json() == {
        "status": "NOT_SENT",
        "response_code": "96",
        "user_message": "No se pudo conectar con el procesador de pagos",
    }
    use_case.execute.assert_called_once()


def test_reverse_http_timeout_is_indeterminate_and_sanitized() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = ProcessorUnavailable(
        "timeout while sending PAN 4111111111111111"
    )
    app.dependency_overrides[get_reverse_payment] = lambda: use_case
    try:
        response = client.post("/v1/reverse", json=_payload())
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 502
    assert response.json() == {
        "status": "INDETERMINATE",
        "response_code": "96",
        "user_message": "Resultado del reverso indeterminado",
    }
    assert "4111111111111111" not in response.text


def test_reverse_http_invalid_iso_response_is_indeterminate() -> None:
    use_case = MagicMock()
    use_case.execute.return_value = ReversalResult(
        status=ReversalStatus.INDETERMINATE,
        response_code="96",
        user_message="Respuesta ISO de reverso inválida",
    )
    app.dependency_overrides[get_reverse_payment] = lambda: use_case
    try:
        response = client.post("/v1/reverse", json=_payload())
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 502
    assert response.json()["status"] == "INDETERMINATE"


def test_reverse_http_unexpected_error_is_indeterminate_and_sanitized() -> None:
    use_case = MagicMock()
    use_case.execute.side_effect = RuntimeError("PAN 4111111111111111 exploded")
    app.dependency_overrides[get_reverse_payment] = lambda: use_case
    try:
        response = client.post("/v1/reverse", json=_payload())
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 502
    assert response.json()["status"] == "INDETERMINATE"
    assert "4111111111111111" not in response.text


def test_reverse_http_rejects_invalid_body_without_echoing_pan() -> None:
    response = client.post(
        "/v1/reverse",
        json=_payload(card_number="411111111111111X"),
    )

    assert response.status_code == 400
    assert response.json()["message"].startswith("card_number:")
    assert "411111111111111X" not in response.text


def test_reverse_openapi_has_no_real_pan_examples() -> None:
    schema = client.get("/openapi.json").text

    assert '"/v1/reverse"' in schema
    assert "4111111111111111" not in schema
