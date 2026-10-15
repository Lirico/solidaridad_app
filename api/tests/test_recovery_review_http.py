from datetime import UTC, datetime
from unittest.mock import MagicMock
from uuid import UUID

from fastapi.testclient import TestClient

from application.payments.review_manual_recovery import (
    ManualRecoveryCase,
    ReviewManualRecovery,
)
from domain.authorization_outcome import AuthorizationOutcome
from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
)
from domain.product import Product
from domain.recovery_alert import RecoveryAlert, RecoveryAlertState
from domain.recovery_review import ManualRecoveryResolution
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from domain.user import UserRole
from main import app
from presentation.dependencies import (
    CurrentUser,
    get_current_central_operator,
    get_current_user,
    get_review_manual_recovery,
)

NOW = datetime(2026, 10, 14, 18, 0, tzinfo=UTC)
client = TestClient(app)


def _case() -> ManualRecoveryCase:
    job = ProcessorJob(
        id=7,
        transaction_id=11,
        operation_type=ProcessorOperationType.REVERSE,
        state=ProcessorJobState.MANUAL_REVIEW,
        result=None,
        attempt_count=2,
        next_attempt_at=NOW,
        worker_id="worker-1",
        claim_token=UUID("00000000-0000-0000-0000-000000000001"),
        processing_started_at=NOW,
        original_stan="000001",
        original_ticket="1",
        reversal_stan="000002",
        last_error_code="INDETERMINATE",
        last_error_detail_sanitized="socket closed",
        created_at=NOW,
        updated_at=NOW,
        completed_at=None,
    )
    transaction = Transaction(
        id=11,
        transaction_number="OP-261014-00000001",
        user_id=2,
        installation_id=3,
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=150,
        status=TransactionStatus.PENDING,
        card_last4="1111",
        card_number="4111111111111111",
        expiration_date="3012",
        authorization_outcome=AuthorizationOutcome.INDETERMINATE,
        stan="000001",
        auth_id=None,
        retrieval_reference=None,
        processor_response_code=None,
        user_message="En revisión",
        idempotency_key="key",
        request_fingerprint="fingerprint",
        created_at=NOW,
        updated_at=NOW,
    )
    alert = RecoveryAlert(
        id=5,
        processor_job_id=job.id,
        cause="INDETERMINATE",
        state=RecoveryAlertState.OPEN,
        opened_at=NOW,
        created_at=NOW,
    )
    return ManualRecoveryCase(
        job=job,
        transaction=transaction,
        alerts=[alert],
        actions=[],
    )


def _clear() -> None:
    app.dependency_overrides.clear()


def test_terminal_user_receives_403_for_internal_recovery_review() -> None:
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=2,
        email="terminal@example.com",
        installation_id="05000001",
    )
    try:
        response = client.get("/v1/internal/recovery/jobs")
    finally:
        _clear()

    assert response.status_code == 403
    assert response.json()["message"] == "Operador central requerido"


def test_central_operator_lists_masked_recovery_case() -> None:
    use_case = MagicMock(spec=ReviewManualRecovery)
    use_case.list_cases.return_value = [_case()]
    app.dependency_overrides[get_current_central_operator] = lambda: CurrentUser(
        user_id=99,
        email="central@example.com",
        installation_id="CENTRAL1",
        role=UserRole.CENTRAL_OPERATOR,
    )
    app.dependency_overrides[get_review_manual_recovery] = lambda: use_case
    try:
        response = client.get("/v1/internal/recovery/jobs")
    finally:
        _clear()

    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["card_last4"] == "1111"
    assert "card_number" not in item
    assert "expiration_date" not in item
    assert "4111111111111111" not in response.text
    assert "3012" not in response.text


def test_central_operator_resolution_carries_operator_and_evidence() -> None:
    use_case = MagicMock(spec=ReviewManualRecovery)
    use_case.resolve.return_value = _case()
    app.dependency_overrides[get_current_central_operator] = lambda: CurrentUser(
        user_id=99,
        email="central@example.com",
        installation_id="CENTRAL1",
        role=UserRole.CENTRAL_OPERATOR,
    )
    app.dependency_overrides[get_review_manual_recovery] = lambda: use_case
    try:
        response = client.post(
            "/v1/internal/recovery/jobs/7/resolve",
            json={
                "resolution": "REVERSED_CONFIRMED",
                "reason": "Confirmado con emisor",
                "external_reference": "CASE-123",
            },
        )
    finally:
        _clear()

    assert response.status_code == 200
    use_case.resolve.assert_called_once_with(
        job_id=7,
        operator_user_id=99,
        resolution=ManualRecoveryResolution.REVERSED_CONFIRMED,
        reason="Confirmado con emisor",
        external_reference="CASE-123",
    )


def test_manual_retry_requires_reason() -> None:
    app.dependency_overrides[get_current_central_operator] = lambda: CurrentUser(
        user_id=99,
        email="central@example.com",
        installation_id="CENTRAL1",
        role=UserRole.CENTRAL_OPERATOR,
    )
    app.dependency_overrides[get_review_manual_recovery] = lambda: MagicMock(
        spec=ReviewManualRecovery
    )
    try:
        response = client.post("/v1/internal/recovery/jobs/7/retry", json={})
    finally:
        _clear()

    assert response.status_code == 400
    assert "reason" in response.json()["message"]
