from datetime import UTC, datetime
from unittest.mock import MagicMock
from uuid import uuid4

from fastapi.testclient import TestClient

from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
    CreateTransactionResult,
)
from domain.exceptions import IdempotencyConflict, InvalidCardNumber
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from main import app
from presentation.dependencies import (
    CurrentUser,
    get_create_transaction,
    get_current_user,
)

client = TestClient(app)


def _tx(**overrides: object) -> Transaction:
    base = dict(
        id=1,
        transaction_number="OP-260716-0001",
        user_id=uuid4(),
        installation_id="inst-1",
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=150,
        status=TransactionStatus.APPROVED,
        card_last4="1111",
        stan="000001",
        auth_id="A1",
        retrieval_reference="R1",
        processor_response_code="00",
        user_message="Pago aprobado",
        idempotency_key="k1",
        request_fingerprint="fp",
        created_at=datetime(2026, 7, 16, 19, 0, tzinfo=UTC),
        updated_at=datetime(2026, 7, 16, 19, 0, tzinfo=UTC),
    )
    base.update(overrides)
    return Transaction(**base)  # type: ignore[arg-type]


def _override(use_case: MagicMock) -> None:
    app.dependency_overrides[get_create_transaction] = lambda: use_case
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=uuid4(),
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )


def _clear() -> None:
    app.dependency_overrides.clear()


def _payload(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "product": "GARRAFA_10",
        "amount": "1.50",
        "card_number": "4111111111111111",
        "cvv": "123",
    }
    body.update(overrides)
    return body


def test_create_transaction_201() -> None:
    use_case = MagicMock(spec=CreateTransaction)
    use_case.execute.return_value = CreateTransactionResult(
        transaction=_tx(),
        http_status=CreateTransactionHttpStatus.CREATED,
    )
    _override(use_case)
    try:
        response = client.post(
            "/v1/transactions",
            json=_payload(),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()

    assert response.status_code == 201
    data = response.json()
    assert data["transaction_number"] == "OP-260716-0001"
    assert data["status"] == "APPROVED"
    assert data["user_message"] == "Pago aprobado"
    assert "card_number" not in data
    assert "cvv" not in data


def test_create_transaction_202_pending() -> None:
    use_case = MagicMock(spec=CreateTransaction)
    use_case.execute.return_value = CreateTransactionResult(
        transaction=_tx(
            status=TransactionStatus.PENDING,
            user_message="Operación en curso, reintente en unos segundos",
        ),
        http_status=CreateTransactionHttpStatus.ACCEPTED,
    )
    _override(use_case)
    try:
        response = client.post(
            "/v1/transactions",
            json=_payload(),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()

    assert response.status_code == 202
    assert response.json()["status"] == "PENDING"


def test_create_transaction_requires_auth() -> None:
    response = client.post("/v1/transactions", json=_payload())
    assert response.status_code == 401


def test_create_transaction_validation_error() -> None:
    _override(MagicMock(spec=CreateTransaction))
    try:
        response = client.post(
            "/v1/transactions",
            json=_payload(product="ARS"),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()
    assert response.status_code == 400


def test_create_transaction_domain_400() -> None:
    use_case = MagicMock(spec=CreateTransaction)
    use_case.execute.side_effect = InvalidCardNumber()
    _override(use_case)
    try:
        response = client.post(
            "/v1/transactions",
            json=_payload(),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()
    assert response.status_code == 400
    assert response.json()["message"] == "Número de tarjeta inválido"


def test_create_transaction_idempotency_conflict() -> None:
    use_case = MagicMock(spec=CreateTransaction)
    use_case.execute.side_effect = IdempotencyConflict()
    _override(use_case)
    try:
        response = client.post(
            "/v1/transactions",
            json=_payload(),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()
    assert response.status_code == 409
