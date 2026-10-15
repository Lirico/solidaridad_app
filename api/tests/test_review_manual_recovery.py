from datetime import UTC, datetime
from unittest.mock import ANY, MagicMock
from uuid import UUID

import pytest

from application.payments.review_manual_recovery import ReviewManualRecovery
from config import Settings
from domain.exceptions import ManualRecoveryConflict, ManualReversalRetryDisabled
from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
)
from domain.product import Product
from domain.recovery_review import ManualRecoveryResolution, RecoveryReviewActionType
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus

NOW = datetime(2026, 10, 14, 18, 0, tzinfo=UTC)


def _job(state: ProcessorJobState = ProcessorJobState.MANUAL_REVIEW) -> ProcessorJob:
    return ProcessorJob(
        id=7,
        transaction_id=11,
        operation_type=ProcessorOperationType.REVERSE,
        state=state,
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


def _transaction() -> Transaction:
    return Transaction(
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


def _use_case(*, manual_retry_enabled: bool = False) -> tuple[
    ReviewManualRecovery,
    MagicMock,
    MagicMock,
    MagicMock,
    MagicMock,
    MagicMock,
]:
    session = MagicMock()
    transactions = MagicMock()
    jobs = MagicMock()
    alerts = MagicMock()
    actions = MagicMock()
    settings = Settings(manual_reversal_retry_enabled=manual_retry_enabled)
    return (
        ReviewManualRecovery(
            session=session,
            transactions=transactions,
            jobs=jobs,
            alerts=alerts,
            actions=actions,
            settings=settings,
            now=lambda: NOW,
        ),
        session,
        transactions,
        jobs,
        alerts,
        actions,
    )


@pytest.mark.parametrize(
    ("resolution", "expected_status"),
    [
        (ManualRecoveryResolution.REVERSED_CONFIRMED, TransactionStatus.FAILED),
        (ManualRecoveryResolution.PROCESSOR_DECLINED, TransactionStatus.DECLINED),
        (
            ManualRecoveryResolution.ACTIVE_APPROVAL_CONFIRMED,
            TransactionStatus.APPROVED,
        ),
    ],
)
def test_resolution_projects_final_status_and_audits_evidence(
    resolution: ManualRecoveryResolution,
    expected_status: TransactionStatus,
) -> None:
    use_case, session, transactions, jobs, alerts, actions = _use_case()
    job = _job()
    transaction = _transaction()
    jobs.get_by_id_for_update.return_value = job
    transactions.get_by_id_for_update.return_value = transaction
    transactions.apply_manual_recovery_resolution.return_value = transaction
    jobs.get_by_id.return_value = _job(ProcessorJobState.COMPLETED)
    alerts.list_for_job.return_value = []
    actions.list_for_job.return_value = []

    result = use_case.resolve(
        job_id=job.id,
        operator_user_id=99,
        resolution=resolution,
        reason="Consulta conciliada con emisor",
        external_reference="CASE-123",
    )

    assert result.job.state is ProcessorJobState.COMPLETED
    jobs.complete_manual_review.assert_called_once_with(
        job_id=job.id,
        result=resolution.value,
        completed_at=NOW,
    )
    assert transactions.apply_manual_recovery_resolution.call_args.kwargs == {
        "transaction_id": transaction.id,
        "status": expected_status,
        "operator_user_id": 99,
        "user_message": ANY,
    }
    actions.record.assert_called_once_with(
        processor_job_id=job.id,
        operator_user_id=99,
        action_type=RecoveryReviewActionType.RESOLUTION,
        resolution=resolution,
        reason="Consulta conciliada con emisor",
        external_reference="CASE-123",
    )
    session.commit.assert_called_once_with()
    session.rollback.assert_not_called()


def test_resolution_rejects_already_resolved_job_without_writing() -> None:
    use_case, session, transactions, jobs, _alerts, actions = _use_case()
    jobs.get_by_id_for_update.return_value = _job(ProcessorJobState.COMPLETED)

    with pytest.raises(ManualRecoveryConflict):
        use_case.resolve(
            job_id=7,
            operator_user_id=99,
            resolution=ManualRecoveryResolution.REVERSED_CONFIRMED,
            reason="evidencia",
            external_reference=None,
        )

    transactions.get_by_id_for_update.assert_not_called()
    actions.record.assert_not_called()
    session.rollback.assert_called_once_with()


def test_manual_retry_is_disabled_by_default() -> None:
    use_case, session, transactions, jobs, _alerts, actions = _use_case()

    with pytest.raises(ManualReversalRetryDisabled):
        use_case.retry(
            job_id=7,
            operator_user_id=99,
            reason="Se confirmó que no se envió el 0400",
            external_reference=None,
        )

    jobs.get_by_id_for_update.assert_not_called()
    transactions.get_by_id_for_update.assert_not_called()
    actions.record.assert_not_called()
    session.commit.assert_not_called()


def test_enabled_manual_retry_transitions_and_audits_reason() -> None:
    use_case, session, transactions, jobs, alerts, actions = _use_case(
        manual_retry_enabled=True
    )
    job = _job()
    transaction = _transaction()
    jobs.get_by_id_for_update.return_value = job
    transactions.get_by_id_for_update.return_value = transaction
    jobs.get_by_id.return_value = _job(ProcessorJobState.RETRY)
    alerts.list_for_job.return_value = []
    actions.list_for_job.return_value = []

    result = use_case.retry(
        job_id=job.id,
        operator_user_id=99,
        reason="El emisor confirmó que el mensaje no salió",
        external_reference="CASE-124",
    )

    assert result.job.state is ProcessorJobState.RETRY
    jobs.retry_manual_review.assert_called_once_with(
        job_id=job.id,
        next_attempt_at=NOW,
    )
    transactions.record_manual_recovery_retry.assert_called_once_with(
        transaction_id=transaction.id,
        operator_user_id=99,
    )
    actions.record.assert_called_once_with(
        processor_job_id=job.id,
        operator_user_id=99,
        action_type=RecoveryReviewActionType.MANUAL_RETRY,
        reason="El emisor confirmó que el mensaje no salió",
        external_reference="CASE-124",
    )
    session.commit.assert_called_once_with()
