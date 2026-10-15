from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from domain.processor_job import (
    InvalidProcessorJobTransition,
    ProcessorJobState,
    ProcessorOperationType,
)
from persistence.models.processor_job import ProcessorJob as ProcessorJobModel
from persistence.repositories.processor_job_repository import ProcessorJobRepository


def _row(state: ProcessorJobState = ProcessorJobState.READY) -> MagicMock:
    now = datetime.now(UTC)
    row = MagicMock(spec=ProcessorJobModel)
    for name, value in {
        "id": 7,
        "transaction_id": 11,
        "operation_type": "REVERSE",
        "state": state.value,
        "result": None,
        "attempt_count": 0,
        "next_attempt_at": now,
        "worker_id": None,
        "claim_token": None,
        "processing_started_at": None,
        "original_stan": "000123",
        "original_ticket": "00000042",
        "reversal_stan": "900123",
        "last_error_code": None,
        "last_error_detail_sanitized": None,
        "created_at": now,
        "updated_at": now,
        "completed_at": None,
    }.items():
        setattr(row, name, value)
    return row


def test_create_and_query_durable_reverse_job() -> None:
    session = MagicMock()

    def add(row: ProcessorJobModel) -> None:
        row.id = 7

    session.add.side_effect = add
    due = datetime.now(UTC)

    created = ProcessorJobRepository(session).create_reverse(
        transaction_id=11,
        original_stan="000123",
        original_ticket="00000042",
        reversal_stan="900123",
        next_attempt_at=due,
    )

    assert created.id == 7
    assert created.operation_type is ProcessorOperationType.REVERSE
    assert created.state is ProcessorJobState.READY
    assert created.next_attempt_at == due
    assert created.attempt_count == 0
    session.flush.assert_called_once()


def test_get_by_transaction_and_missing_id() -> None:
    session = MagicMock()
    session.scalar.return_value = _row()
    repo = ProcessorJobRepository(session)

    found = repo.get_by_transaction(
        transaction_id=11,
        operation_type=ProcessorOperationType.REVERSE,
    )

    assert found is not None
    assert found.reversal_stan == "900123"
    session.get.return_value = None
    assert repo.get_by_id(999) is None


def test_valid_job_state_transitions_are_persisted() -> None:
    session = MagicMock()
    row = _row()
    session.get.return_value = row
    repo = ProcessorJobRepository(session)
    started = datetime.now(UTC)
    token = uuid4()

    processing = repo.transition(
        job_id=7,
        target=ProcessorJobState.PROCESSING,
        worker_id="api-1",
        claim_token=token,
        processing_started_at=started,
    )

    assert processing is not None
    assert processing.state is ProcessorJobState.PROCESSING
    assert processing.claim_token == token

    retry_at = started + timedelta(seconds=5)
    retry = repo.transition(
        job_id=7,
        target=ProcessorJobState.RETRY,
        next_attempt_at=retry_at,
        last_error_code="NOT_SENT",
        last_error_detail_sanitized="connection refused",
    )
    assert retry is not None
    assert retry.state is ProcessorJobState.RETRY
    assert retry.next_attempt_at == retry_at
    assert retry.last_error_code == "NOT_SENT"


def test_claims_one_due_reverse_job_with_a_fresh_processing_claim() -> None:
    session = MagicMock()
    row = _row(ProcessorJobState.RETRY)
    row.attempt_count = 1
    session.scalar.return_value = row
    repo = ProcessorJobRepository(session)
    claimed_at = datetime(2026, 10, 14, 12, tzinfo=UTC)
    token = uuid4()

    claimed = repo.claim_next_due_reverse(
        worker_id="worker-1",
        claim_token=token,
        claimed_at=claimed_at,
    )

    assert claimed is not None
    assert claimed.state is ProcessorJobState.PROCESSING
    assert claimed.worker_id == "worker-1"
    assert claimed.claim_token == token
    assert claimed.processing_started_at == claimed_at
    assert claimed.attempt_count == 2
    statement = session.scalar.call_args.args[0]
    assert "FOR UPDATE" in str(statement)
    assert statement._for_update_arg.skip_locked is True
    session.flush.assert_called_once()


def test_claim_ignores_when_no_due_reverse_job_is_available() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    claimed = ProcessorJobRepository(session).claim_next_due_reverse(
        worker_id="worker-1",
        claim_token=uuid4(),
        claimed_at=datetime.now(UTC),
    )

    assert claimed is None
    session.flush.assert_not_called()


def test_moves_one_stale_processing_job_to_manual_review() -> None:
    session = MagicMock()
    row = _row(ProcessorJobState.PROCESSING)
    row.worker_id = "worker-1"
    row.claim_token = uuid4()
    row.processing_started_at = datetime(2026, 10, 14, 11, 59, tzinfo=UTC)
    session.scalar.return_value = row
    reviewed_at = datetime(2026, 10, 14, 12, tzinfo=UTC)

    moved = ProcessorJobRepository(
        session
    ).move_next_stale_processing_to_manual_review(
        processing_started_before=reviewed_at,
        reviewed_at=reviewed_at,
    )

    assert moved is not None
    assert moved.state is ProcessorJobState.MANUAL_REVIEW
    assert moved.last_error_code == "PROCESSING_TIMEOUT"
    statement = session.scalar.call_args.args[0]
    assert "FOR UPDATE" in str(statement)
    assert statement._for_update_arg.skip_locked is True
    session.flush.assert_called_once()


def test_competing_monitors_only_move_one_stale_processing_job() -> None:
    first_session = MagicMock()
    second_session = MagicMock()
    row = _row(ProcessorJobState.PROCESSING)
    row.worker_id = "worker-1"
    row.claim_token = uuid4()
    row.processing_started_at = datetime(2026, 10, 14, 11, 59, tzinfo=UTC)
    first_session.scalar.return_value = row
    second_session.scalar.return_value = None
    reviewed_at = datetime(2026, 10, 14, 12, tzinfo=UTC)

    first = ProcessorJobRepository(
        first_session
    ).move_next_stale_processing_to_manual_review(
        processing_started_before=reviewed_at,
        reviewed_at=reviewed_at,
    )
    second = ProcessorJobRepository(
        second_session
    ).move_next_stale_processing_to_manual_review(
        processing_started_before=reviewed_at,
        reviewed_at=reviewed_at,
    )

    assert first is not None
    assert second is None
    first_session.flush.assert_called_once()
    second_session.flush.assert_not_called()


def test_two_competing_sessions_only_one_claims_the_same_job() -> None:
    first_session = MagicMock()
    second_session = MagicMock()
    row = _row()
    first_session.scalar.return_value = row
    # PostgreSQL SKIP LOCKED makes the second session skip the locked row.
    second_session.scalar.return_value = None
    claimed_at = datetime.now(UTC)

    first = ProcessorJobRepository(first_session).claim_next_due_reverse(
        worker_id="worker-1",
        claim_token=uuid4(),
        claimed_at=claimed_at,
    )
    second = ProcessorJobRepository(second_session).claim_next_due_reverse(
        worker_id="worker-2",
        claim_token=uuid4(),
        claimed_at=claimed_at,
    )

    assert first is not None
    assert first.state is ProcessorJobState.PROCESSING
    assert second is None
    first_session.flush.assert_called_once()
    second_session.flush.assert_not_called()


def test_finalize_claim_requires_the_current_processing_token() -> None:
    session = MagicMock()
    session.execute.return_value.scalar_one_or_none.return_value = None
    token = uuid4()
    finalized = ProcessorJobRepository(session).finalize_claim(
        job_id=7,
        claim_token=token,
        target=ProcessorJobState.MANUAL_REVIEW,
        finalized_at=datetime.now(UTC),
        last_error_code="INDETERMINATE",
    )

    assert finalized is False
    statement = session.execute.call_args.args[0]
    assert "processor_jobs.state" in str(statement)
    assert "processor_jobs.claim_token" in str(statement)


def test_late_completion_cannot_overwrite_manual_review() -> None:
    session = MagicMock()
    session.execute.return_value.scalar_one_or_none.return_value = None

    finalized = ProcessorJobRepository(session).finalize_claim(
        job_id=7,
        claim_token=uuid4(),
        target=ProcessorJobState.COMPLETED,
        finalized_at=datetime.now(UTC),
        result="REVERSED_CONFIRMED",
    )

    assert finalized is False
    statement = session.execute.call_args.args[0]
    assert "processor_jobs.state" in str(statement)


def test_invalid_or_incomplete_job_transitions_are_rejected() -> None:
    session = MagicMock()
    row = _row()
    session.get.return_value = row
    repo = ProcessorJobRepository(session)

    with pytest.raises(InvalidProcessorJobTransition, match="READY to COMPLETED"):
        repo.transition(job_id=7, target=ProcessorJobState.COMPLETED)

    with pytest.raises(ValueError, match="PROCESSING requires"):
        repo.transition(job_id=7, target=ProcessorJobState.PROCESSING)

    row.state = ProcessorJobState.PROCESSING.value
    with pytest.raises(ValueError, match="RETRY requires"):
        repo.transition(job_id=7, target=ProcessorJobState.RETRY)
    with pytest.raises(ValueError, match="COMPLETED requires"):
        repo.transition(job_id=7, target=ProcessorJobState.COMPLETED)


def test_completed_jobs_are_terminal_and_missing_job_is_ignored() -> None:
    session = MagicMock()
    session.get.return_value = _row(ProcessorJobState.COMPLETED)
    repo = ProcessorJobRepository(session)

    with pytest.raises(InvalidProcessorJobTransition, match="COMPLETED to RETRY"):
        repo.transition(
            job_id=7,
            target=ProcessorJobState.RETRY,
            next_attempt_at=datetime.now(UTC),
        )

    session.get.return_value = None
    assert repo.transition(job_id=999, target=ProcessorJobState.MANUAL_REVIEW) is None
