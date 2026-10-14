from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.payments.get_transaction_status import GetTransactionStatus
from application.payments.public_transaction_status import PendingReason
from domain.exceptions import TransactionNotFound
from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus


def _transaction(status: TransactionStatus = TransactionStatus.PENDING) -> Transaction:
    now = datetime.now(UTC)
    return Transaction(
        id=1,
        transaction_number="OP-261014-00000001",
        user_id=2,
        installation_id=3,
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=150,
        status=status,
        card_last4="1111",
        stan="000001",
        auth_id=None,
        retrieval_reference=None,
        processor_response_code=None,
        user_message="Operación en curso, reintente en unos segundos",
        idempotency_key="key-1",
        request_fingerprint="fp",
        created_at=now,
        updated_at=now,
    )


def _reverse_job(state: ProcessorJobState) -> ProcessorJob:
    now = datetime.now(UTC)
    return ProcessorJob(
        id=4,
        transaction_id=1,
        operation_type=ProcessorOperationType.REVERSE,
        state=state,
        result=None,
        attempt_count=0,
        next_attempt_at=now,
        worker_id=None,
        claim_token=None,
        processing_started_at=None,
        original_stan="000001",
        original_ticket="00000001",
        reversal_stan="000002",
        last_error_code=None,
        last_error_detail_sanitized=None,
        created_at=now,
        updated_at=now,
        completed_at=None,
    )


@pytest.mark.parametrize(
    "job_state",
    [
        ProcessorJobState.READY,
        ProcessorJobState.PROCESSING,
        ProcessorJobState.RETRY,
    ],
)
def test_active_reversal_projects_pending_processing(
    job_state: ProcessorJobState,
) -> None:
    transactions = MagicMock()
    jobs = MagicMock()
    transactions.get_by_transaction_number.return_value = _transaction()
    jobs.get_by_transaction.return_value = _reverse_job(job_state)

    result = GetTransactionStatus(transactions, jobs).execute(
        terminal_id="05000001",
        transaction_number="OP-261014-00000001",
    )

    assert result.public_status.status == "PENDING"
    assert result.public_status.reason is PendingReason.PROCESSING
    assert result.public_status.poll_after_seconds == 2
    assert result.public_status.may_start_new_sale is False
    transactions.get_by_transaction_number.assert_called_once_with(
        terminal_id="05000001",
        transaction_number="OP-261014-00000001",
    )
    jobs.get_by_transaction.assert_called_once_with(
        transaction_id=1,
        operation_type=ProcessorOperationType.REVERSE,
    )


def test_manual_review_projects_terminal_instruction_without_job_details() -> None:
    transactions = MagicMock()
    jobs = MagicMock()
    transactions.get_by_transaction_number.return_value = _transaction()
    jobs.get_by_transaction.return_value = _reverse_job(ProcessorJobState.MANUAL_REVIEW)

    result = GetTransactionStatus(transactions, jobs).execute(
        terminal_id="05000001",
        transaction_number="OP-261014-00000001",
    )

    assert result.public_status.status == "PENDING"
    assert result.public_status.reason is PendingReason.UNDER_REVIEW
    assert result.public_status.poll_after_seconds is None
    assert result.public_status.may_start_new_sale is True
    assert "MANUAL_REVIEW" not in result.public_status.user_message


@pytest.mark.parametrize(
    "status",
    [
        TransactionStatus.APPROVED,
        TransactionStatus.DECLINED,
        TransactionStatus.FAILED,
    ],
)
def test_final_authorization_statuses_do_not_expose_recovery_details(
    status: TransactionStatus,
) -> None:
    transactions = MagicMock()
    jobs = MagicMock()
    transactions.get_by_transaction_number.return_value = _transaction(status)
    jobs.get_by_transaction.return_value = _reverse_job(ProcessorJobState.MANUAL_REVIEW)

    result = GetTransactionStatus(transactions, jobs).execute(
        terminal_id="05000001",
        transaction_number="OP-261014-00000001",
    )

    assert result.public_status.status == status.value
    assert result.public_status.reason is None
    assert result.public_status.poll_after_seconds is None
    assert result.public_status.may_start_new_sale is True


def test_unknown_transaction_for_terminal_is_not_found() -> None:
    transactions = MagicMock()
    transactions.get_by_transaction_number.return_value = None

    with pytest.raises(TransactionNotFound):
        GetTransactionStatus(transactions, MagicMock()).execute(
            terminal_id="05000001",
            transaction_number="OP-261014-00000001",
        )
