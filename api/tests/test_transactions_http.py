from datetime import UTC, datetime
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
    CreateTransactionResult,
)
from application.payments.list_transactions import (
    ListTransactions,
    ListTransactionsResult,
)
from application.payments.void_transaction import (
    VoidTransaction,
    VoidTransactionHttpStatus,
    VoidTransactionResult,
)
from domain.exceptions import (
    CardMismatch,
    IdempotencyConflict,
    InvalidCardNumber,
    TransactionNotFound,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from main import app
from presentation.dependencies import (
    CurrentUser,
    get_create_transaction,
    get_current_user,
    get_list_transactions,
    get_void_transaction,
)

client = TestClient(app)


def _tx(**overrides: object) -> Transaction:
    base = dict(
        id=1,
        transaction_number="OP-260716-00000001",
        user_id=1,
        installation_id=1,
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
        user_id=1,
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )


def _override_list(use_case: MagicMock) -> None:
    app.dependency_overrides[get_list_transactions] = lambda: use_case
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=1,
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
    assert data["transaction_number"] == "OP-260716-00000001"
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


def test_create_transaction_band_magnetic_empty_cvv() -> None:
    """La banda magnética (entry_mode 022) no envía CVV: el schema lo acepta."""
    use_case = MagicMock(spec=CreateTransaction)
    use_case.execute.return_value = CreateTransactionResult(
        transaction=_tx(),
        http_status=CreateTransactionHttpStatus.CREATED,
    )
    _override(use_case)
    try:
        response = client.post(
            "/v1/transactions",
            json=_payload(
                cvv="",
                entry_mode="022",
                track2="6063007014007403=2912",
            ),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()

    assert response.status_code == 201
    use_case.execute.assert_called_once()
    kwargs = use_case.execute.call_args.kwargs
    assert kwargs["cvv"] == ""
    assert kwargs["entry_mode"] == "022"
    assert kwargs["track2"] == "6063007014007403=2912"


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


def test_list_transactions_200() -> None:
    use_case = MagicMock(spec=ListTransactions)
    use_case.execute.return_value = ListTransactionsResult(
        transactions=[_tx()],
        total=1,
    )
    _override_list(use_case)
    try:
        response = client.get("/v1/transactions")
    finally:
        _clear()

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    item = data["items"][0]
    assert item["transaction_number"] == "OP-260716-00000001"
    assert item["product"] == "GARRAFA_10"
    assert item["amount"] == "1.5"
    assert item["card_last4"] == "1111"
    assert item["status"] == "APPROVED"
    assert item["user_message"] == "Pago aprobado"


def test_list_transactions_empty() -> None:
    use_case = MagicMock(spec=ListTransactions)
    use_case.execute.return_value = ListTransactionsResult(
        transactions=[],
        total=0,
    )
    _override_list(use_case)
    try:
        response = client.get("/v1/transactions")
    finally:
        _clear()

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 0
    assert data["items"] == []


def test_list_transactions_requires_auth() -> None:
    response = client.get("/v1/transactions")
    assert response.status_code == 401


def test_list_transactions_pagination_params() -> None:
    use_case = MagicMock(spec=ListTransactions)
    use_case.execute.return_value = ListTransactionsResult(
        transactions=[_tx()],
        total=1,
    )
    _override_list(use_case)
    try:
        response = client.get("/v1/transactions?limit=10&offset=5")
    finally:
        _clear()

    assert response.status_code == 200
    use_case.execute.assert_called_once_with(
        terminal_id="inst-1",
        limit=10,
        offset=5,
    )


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


def test_void_transaction_200() -> None:
    use_case = MagicMock(spec=VoidTransaction)
    use_case.execute.return_value = VoidTransactionResult(
        transaction=_tx(
            status=TransactionStatus.VOIDED,
            user_message="Anulación aprobada",
        ),
        http_status=VoidTransactionHttpStatus.OK,
        user_message="Anulación aprobada",
    )
    app.dependency_overrides[get_void_transaction] = lambda: use_case
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=1,
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )
    try:
        response = client.post(
            "/v1/transactions/OP-260716-00000001/void",
            json={"card_number": "4111111111111111"},
            headers={"Idempotency-Key": "void-1"},
        )
    finally:
        _clear()

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "VOIDED"
    assert data["user_message"] == "Anulación aprobada"
    use_case.execute.assert_called_once()


def test_void_transaction_404() -> None:
    use_case = MagicMock(spec=VoidTransaction)
    use_case.execute.side_effect = TransactionNotFound()
    app.dependency_overrides[get_void_transaction] = lambda: use_case
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=1,
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )
    try:
        response = client.post(
            "/v1/transactions/OP-260716-99999999/void",
            json={"card_number": "4111111111111111"},
            headers={"Idempotency-Key": "void-1"},
        )
    finally:
        _clear()
    assert response.status_code == 404


def test_void_transaction_card_mismatch_400() -> None:
    use_case = MagicMock(spec=VoidTransaction)
    use_case.execute.side_effect = CardMismatch()
    app.dependency_overrides[get_void_transaction] = lambda: use_case
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=1,
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )
    try:
        response = client.post(
            "/v1/transactions/OP-260716-00000001/void",
            json={"card_number": "4111111111119999"},
            headers={"Idempotency-Key": "void-1"},
        )
    finally:
        _clear()
    assert response.status_code == 400
