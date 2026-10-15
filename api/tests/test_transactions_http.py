from datetime import UTC, datetime
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.payments.close_batch import CloseBatch, CloseBatchResult
from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
    CreateTransactionResult,
)
from application.payments.get_transaction_status import (
    GetTransactionStatus,
    GetTransactionStatusResult,
)
from application.payments.list_transactions import (
    ListTransactions,
    ListTransactionsResult,
)
from application.payments.public_transaction_status import (
    PendingReason,
    PublicTransactionStatus,
)
from application.payments.void_transaction import (
    VoidTransaction,
    VoidTransactionHttpStatus,
    VoidTransactionResult,
)
from domain.batch_close import BatchClose
from domain.exceptions import (
    BatchCloseHasInFlightTransactions,
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
    get_close_batch,
    get_create_transaction,
    get_current_user,
    get_list_transactions,
    get_transaction_status,
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


def _override_status(use_case: MagicMock) -> None:
    app.dependency_overrides[get_transaction_status] = lambda: use_case
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=1,
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )


def _override_close(use_case: MagicMock) -> None:
    app.dependency_overrides[get_close_batch] = lambda: use_case
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


def _batch_close() -> BatchClose:
    return BatchClose(
        id=3,
        installation_id=1,
        terminal_id="inst-1",
        closed_by_user_id=1,
        idempotency_key="close-1",
        closed_at=datetime(2026, 10, 6, 18, 0, tzinfo=UTC),
    )


def test_create_transaction_201() -> None:
    use_case = MagicMock(spec=CreateTransaction)
    use_case.execute.return_value = CreateTransactionResult(
        transaction=_tx(
            card_number="4111111111111111",
            expiration_date="3012",
        ),
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
    assert "expiration_date" not in data
    assert "4111111111111111" not in response.text
    assert "3012" not in response.text


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
    assert response.json()["reason"] == "PROCESSING"
    assert response.json()["poll_after_seconds"] == 2
    assert response.json()["may_start_new_sale"] is False


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


def test_create_transaction_accepts_empty_cvv() -> None:
    """El schema conserva CVV solo como campo opcional de compatibilidad."""
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
            ),
            headers={"Idempotency-Key": "k1"},
        )
    finally:
        _clear()

    assert response.status_code == 201
    use_case.execute.assert_called_once()
    kwargs = use_case.execute.call_args.kwargs
    assert kwargs["cvv"] == ""



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


def test_close_batch_201_returns_receipt_operations() -> None:
    use_case = MagicMock(spec=CloseBatch)
    use_case.execute.return_value = CloseBatchResult(
        batch_close=_batch_close(),
        transactions=[_tx()],
    )
    _override_close(use_case)
    try:
        response = client.post(
            "/v1/transactions/batch-close",
            headers={"Idempotency-Key": "close-1"},
        )
    finally:
        _clear()

    assert response.status_code == 201
    assert response.json()["batch_close_id"] == 3
    assert response.json()["total"] == 1
    assert response.json()["items"][0]["transaction_number"] == _tx().transaction_number
    use_case.execute.assert_called_once_with(
        installation_id="inst-1",
        user_id=1,
        idempotency_key="close-1",
    )


def test_close_batch_rejects_in_flight_operations() -> None:
    use_case = MagicMock(spec=CloseBatch)
    use_case.execute.side_effect = BatchCloseHasInFlightTransactions()
    _override_close(use_case)
    try:
        response = client.post(
            "/v1/transactions/batch-close",
            headers={"Idempotency-Key": "close-1"},
        )
    finally:
        _clear()

    assert response.status_code == 409
    assert response.json()["message"] == (
        "No se puede cerrar el lote: hay recuperaciones pendientes. "
        "Espere a que finalicen o solicite una resolución administrativa"
    )


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


def test_get_transaction_processing_returns_202_with_polling_instructions() -> None:
    use_case = MagicMock(spec=GetTransactionStatus)
    use_case.execute.return_value = GetTransactionStatusResult(
        transaction=_tx(status=TransactionStatus.PENDING),
        public_status=PublicTransactionStatus(
            status="PENDING",
            reason=PendingReason.PROCESSING,
            user_message="Operación en curso, reintente en unos segundos",
            poll_after_seconds=2,
            may_start_new_sale=False,
        ),
    )
    _override_status(use_case)
    try:
        response = client.get("/v1/transactions/OP-260716-00000001")
    finally:
        _clear()

    assert response.status_code == 202
    assert response.headers["retry-after"] == "2"
    assert response.json() == {
        "transaction_number": "OP-260716-00000001",
        "status": "PENDING",
        "reason": "PROCESSING",
        "user_message": "Operación en curso, reintente en unos segundos",
        "poll_after_seconds": 2,
        "may_start_new_sale": False,
        "created_at": "2026-07-16T19:00:00Z",
    }
    use_case.execute.assert_called_once_with(
        terminal_id="inst-1",
        transaction_number="OP-260716-00000001",
    )


def test_get_transaction_under_review_stops_polling_and_allows_new_sale() -> None:
    use_case = MagicMock(spec=GetTransactionStatus)
    use_case.execute.return_value = GetTransactionStatusResult(
        transaction=_tx(status=TransactionStatus.PENDING),
        public_status=PublicTransactionStatus(
            status="PENDING",
            reason=PendingReason.UNDER_REVIEW,
            user_message="Verifique la operación con casa central.",
            poll_after_seconds=None,
            may_start_new_sale=True,
        ),
    )
    _override_status(use_case)
    try:
        response = client.get("/v1/transactions/OP-260716-00000001")
    finally:
        _clear()

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "PENDING"
    assert data["reason"] == "UNDER_REVIEW"
    assert data["poll_after_seconds"] is None
    assert data["may_start_new_sale"] is True


def test_get_transaction_hides_processor_job_details_for_final_status() -> None:
    use_case = MagicMock(spec=GetTransactionStatus)
    use_case.execute.return_value = GetTransactionStatusResult(
        transaction=_tx(),
        public_status=PublicTransactionStatus(
            status="APPROVED",
            reason=None,
            user_message="Pago aprobado",
            poll_after_seconds=None,
            may_start_new_sale=True,
        ),
    )
    _override_status(use_case)
    try:
        response = client.get("/v1/transactions/OP-260716-00000001")
    finally:
        _clear()

    assert response.status_code == 200
    data = response.json()
    assert data["reason"] is None
    assert data["poll_after_seconds"] is None
    assert data["may_start_new_sale"] is True
    assert "processor_job" not in response.text
    assert "READY" not in response.text


def test_get_transaction_hides_transactions_from_other_terminals() -> None:
    use_case = MagicMock(spec=GetTransactionStatus)
    use_case.execute.side_effect = TransactionNotFound()
    _override_status(use_case)
    try:
        response = client.get("/v1/transactions/OP-260716-00000001")
    finally:
        _clear()

    assert response.status_code == 404
    assert response.json() == {"message": "Transacción no encontrada"}
    use_case.execute.assert_called_once_with(
        terminal_id="inst-1",
        transaction_number="OP-260716-00000001",
    )


def test_transaction_openapi_documents_pending_and_not_found_contracts() -> None:
    schema = app.openapi()
    post_responses = schema["paths"]["/v1/transactions"]["post"]["responses"]
    get_responses = schema["paths"]["/v1/transactions/{transaction_number}"]["get"][
        "responses"
    ]

    assert {"201", "202"}.issubset(post_responses)
    assert "idempotent replay" in post_responses["202"]["description"].lower()
    assert {"202", "404"}.issubset(get_responses)


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
