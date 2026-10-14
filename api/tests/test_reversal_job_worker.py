import logging
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import MagicMock
from uuid import UUID

import pytest

from application.payments.ports import ReversalOutcome, ReverseResult
from application.payments.reversal_job_worker import ReversalJobWorker
from domain.payment_processing_config import PaymentProcessingConfig
from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus

NOW = datetime(2026, 10, 14, 12, tzinfo=UTC)
TOKEN = UUID("12345678-1234-5678-1234-567812345678")


def _job(**overrides: object) -> ProcessorJob:
    values = {
        "id": 7,
        "transaction_id": 11,
        "operation_type": ProcessorOperationType.REVERSE,
        "state": ProcessorJobState.PROCESSING,
        "result": None,
        "attempt_count": 1,
        "next_attempt_at": NOW,
        "worker_id": "worker-1",
        "claim_token": TOKEN,
        "processing_started_at": NOW,
        "original_stan": "000123",
        "original_ticket": "00000042",
        "reversal_stan": "900123",
        "last_error_code": None,
        "last_error_detail_sanitized": None,
        "created_at": NOW,
        "updated_at": NOW,
        "completed_at": None,
    }
    values.update(overrides)
    return ProcessorJob(**values)  # type: ignore[arg-type]


def _transaction(**overrides: object) -> Transaction:
    values = {
        "id": 11,
        "transaction_number": "OP-261014-00000011",
        "user_id": 1,
        "installation_id": 1,
        "terminal_id": "05000001",
        "product": Product.GARRAFA_10,
        "processor_product_code": "993",
        "amount_minor": 200,
        "status": TransactionStatus.PENDING,
        "card_last4": "1111",
        "card_number": "4111111111111111",
        "expiration_date": "2912",
        "stan": "000123",
        "auth_id": None,
        "retrieval_reference": None,
        "processor_response_code": None,
        "user_message": "Operación en curso",
        "idempotency_key": "key-1",
        "request_fingerprint": "fingerprint",
        "created_at": NOW,
        "updated_at": NOW,
        "processor_ticket": "00000042",
    }
    values.update(overrides)
    return Transaction(**values)  # type: ignore[arg-type]


def _config(**overrides: object) -> PaymentProcessingConfig:
    values = {
        "id": 1,
        "config_name": "default",
        "max_authorization_attempts": 3,
        "authorization_initial_delay_ms": 100,
        "authorization_max_delay_ms": 500,
        "authorization_backoff_multiplier": Decimal("2"),
        "max_reversal_attempts": 2,
        "reversal_initial_delay_seconds": 5,
        "reversal_max_delay_seconds": 30,
        "reversal_backoff_multiplier": Decimal("2"),
        "jitter_percentage": 0,
        "processing_timeout_seconds": 60,
        "worker_poll_interval_seconds": Decimal("1"),
        "created_at": NOW,
        "updated_at": NOW,
    }
    values.update(overrides)
    return PaymentProcessingConfig(**values)  # type: ignore[arg-type]


def _build(
    *,
    claimed: ProcessorJob | None = None,
    transaction: Transaction | None = None,
    outcome: ReversalOutcome = ReversalOutcome.REVERSED_CONFIRMED,
) -> tuple[
    ReversalJobWorker,
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
    configs = MagicMock()
    gateway = MagicMock()
    jobs.claim_next_due_reverse.return_value = claimed or _job()
    jobs.finalize_claim.return_value = True
    transactions.get_by_id.return_value = transaction or _transaction()
    configs.get_default.return_value = _config()
    gateway.reverse.return_value = ReverseResult(outcome=outcome, response_code="00")
    worker = ReversalJobWorker(
        worker_id="worker-1",
        session=session,
        transactions=transactions,
        jobs=jobs,
        alerts=alerts,
        configs=configs,
        gateway=gateway,
        now=lambda: NOW,
        random_value=lambda: 0.5,
        claim_token_factory=lambda: TOKEN,
    )
    return worker, session, transactions, jobs, alerts, gateway


def test_run_once_commits_claim_before_sending_reversal() -> None:
    worker, session, transactions, jobs, _, gateway = _build()

    def reverse(request: object) -> ReverseResult:
        assert session.commit.call_count == 1
        return ReverseResult(
            outcome=ReversalOutcome.REVERSED_CONFIRMED,
            response_code="00",
        )

    gateway.reverse.side_effect = reverse

    assert worker.run_once() is True

    jobs.claim_next_due_reverse.assert_called_once_with(
        worker_id="worker-1",
        claim_token=TOKEN,
        claimed_at=NOW,
    )
    request = gateway.reverse.call_args.args[0]
    assert request.product_code == "993"
    assert request.amount_minor == 200
    assert request.card_number == "4111111111111111"
    assert request.expiration_date == "2912"
    assert request.terminal_id == "05000001"
    assert request.original_stan == "000123"
    assert request.original_ticket == "00000042"
    assert request.reversal_stan == "900123"
    assert session.commit.call_count == 2
    jobs.finalize_claim.assert_called_once_with(
        job_id=7,
        claim_token=TOKEN,
        target=ProcessorJobState.COMPLETED,
        finalized_at=NOW,
        result=ReversalOutcome.REVERSED_CONFIRMED.value,
    )
    update = transactions.update_result.call_args.kwargs
    assert update["transaction_id"] == 11
    assert update["status"] is TransactionStatus.FAILED
    assert update["processor_response_code"] == "00"


def test_run_once_retries_only_definitely_unsent_result_with_attempts_left() -> None:
    worker, session, _, jobs, _, _ = _build(outcome=ReversalOutcome.NOT_SENT)

    assert worker.run_once() is True

    jobs.finalize_claim.assert_called_once_with(
        job_id=7,
        claim_token=TOKEN,
        target=ProcessorJobState.RETRY,
        finalized_at=NOW,
        next_attempt_at=datetime(2026, 10, 14, 12, 0, 5, tzinfo=UTC),
        last_error_code=ReversalOutcome.NOT_SENT.value,
    )
    assert session.commit.call_count == 2


@pytest.mark.parametrize(
    ("outcome", "attempt_count", "error_code"),
    [
        (ReversalOutcome.NOT_SENT, 2, "NOT_SENT"),
        (ReversalOutcome.PROCESSOR_DECLINED, 1, "PROCESSOR_DECLINED"),
        (ReversalOutcome.INDETERMINATE, 1, "INDETERMINATE"),
    ],
)
def test_run_once_moves_unrecoverable_outcomes_to_manual_review(
    outcome: ReversalOutcome,
    attempt_count: int,
    error_code: str,
) -> None:
    worker, session, _, jobs, _, _ = _build(
        claimed=_job(attempt_count=attempt_count),
        outcome=outcome,
    )

    assert worker.run_once() is True

    call = jobs.finalize_claim.call_args.kwargs
    assert call["target"] is ProcessorJobState.MANUAL_REVIEW
    assert call["last_error_code"] == error_code
    assert session.commit.call_count == 2


def test_run_once_marks_missing_recovery_data_for_manual_review() -> None:
    worker, session, _, jobs, _, gateway = _build(
        transaction=_transaction(expiration_date=None)
    )

    assert worker.run_once() is True

    gateway.reverse.assert_not_called()
    jobs.finalize_claim.assert_called_once_with(
        job_id=7,
        claim_token=TOKEN,
        target=ProcessorJobState.MANUAL_REVIEW,
        finalized_at=NOW,
        last_error_code="RECOVERY_DATA_MISSING",
        last_error_detail_sanitized=None,
    )
    assert session.commit.call_count == 2


def test_manual_review_opens_a_sanitized_durable_alert(
    caplog: pytest.LogCaptureFixture,
) -> None:
    worker, _, _, _, alerts, _ = _build(outcome=ReversalOutcome.INDETERMINATE)
    alerts.open_for_job.return_value = True

    with caplog.at_level(logging.WARNING):
        assert worker.run_once() is True

    alerts.open_for_job.assert_called_once_with(
        processor_job_id=7,
        cause=ReversalOutcome.INDETERMINATE.value,
        opened_at=NOW,
    )
    record = caplog.records[-1]
    assert record.event_name == "recovery_alert_opened"
    assert record.processor_job_id == 7
    assert record.transaction_id == 11
    assert record.cause == ReversalOutcome.INDETERMINATE.value
    assert "4111111111111111" not in record.__dict__.values()
    assert "2912" not in record.__dict__.values()


def test_late_gateway_result_with_an_old_claim_token_changes_nothing() -> None:
    worker, session, transactions, jobs, _, _ = _build()
    jobs.finalize_claim.return_value = False

    assert worker.run_once() is True

    transactions.update_result.assert_not_called()
    session.rollback.assert_called_once()


def test_run_once_returns_false_without_due_work() -> None:
    worker, session, transactions, jobs, _, gateway = _build()
    jobs.claim_next_due_reverse.return_value = None

    assert worker.run_once() is False

    session.commit.assert_called_once()
    transactions.get_by_id.assert_not_called()
    gateway.reverse.assert_not_called()


def test_worker_requires_a_non_empty_identifier() -> None:
    with pytest.raises(ValueError, match="worker_id"):
        ReversalJobWorker(
            worker_id=" ",
            session=MagicMock(),
            transactions=MagicMock(),
            jobs=MagicMock(),
            alerts=MagicMock(),
            configs=MagicMock(),
            gateway=MagicMock(),
        )
