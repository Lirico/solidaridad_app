"""Persistence operations for durable processor jobs."""

from datetime import UTC, datetime
from typing import NamedTuple
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
    validate_processor_job_transition,
)
from persistence.models.processor_job import ProcessorJob as ProcessorJobModel


class RecoveryStateAggregate(NamedTuple):
    state: str
    job_count: int
    oldest_created_at: datetime | None
    max_attempt_count: int
    max_resolution_seconds: float | None


def _to_domain(row: ProcessorJobModel) -> ProcessorJob:
    return ProcessorJob(
        id=row.id,
        transaction_id=row.transaction_id,
        operation_type=ProcessorOperationType(row.operation_type),
        state=ProcessorJobState(row.state),
        result=row.result,
        attempt_count=row.attempt_count,
        next_attempt_at=row.next_attempt_at,
        worker_id=row.worker_id,
        claim_token=row.claim_token,
        processing_started_at=row.processing_started_at,
        original_stan=row.original_stan,
        original_ticket=row.original_ticket,
        reversal_stan=row.reversal_stan,
        last_error_code=row.last_error_code,
        last_error_detail_sanitized=row.last_error_detail_sanitized,
        created_at=row.created_at,
        updated_at=row.updated_at,
        completed_at=row.completed_at,
    )


class ProcessorJobRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_id(self, job_id: int) -> ProcessorJob | None:
        row = self._session.get(ProcessorJobModel, job_id)
        return _to_domain(row) if row is not None else None

    def get_by_transaction(
        self,
        *,
        transaction_id: int,
        operation_type: ProcessorOperationType,
    ) -> ProcessorJob | None:
        row = self._session.scalar(
            select(ProcessorJobModel).where(
                ProcessorJobModel.transaction_id == transaction_id,
                ProcessorJobModel.operation_type == operation_type.value,
            )
        )
        return _to_domain(row) if row is not None else None

    def create_reverse(
        self,
        *,
        transaction_id: int,
        original_stan: str,
        original_ticket: str,
        reversal_stan: str,
        next_attempt_at: datetime,
    ) -> ProcessorJob:
        now = datetime.now(UTC)
        row = ProcessorJobModel(
            transaction_id=transaction_id,
            operation_type=ProcessorOperationType.REVERSE.value,
            state=ProcessorJobState.READY.value,
            attempt_count=0,
            next_attempt_at=next_attempt_at,
            original_stan=original_stan,
            original_ticket=original_ticket,
            reversal_stan=reversal_stan,
            created_at=now,
            updated_at=now,
        )
        self._session.add(row)
        self._session.flush()
        return _to_domain(row)

    def cancel_unsent_reverse(
        self,
        *,
        transaction_id: int,
        cancelled_at: datetime,
        reason: str,
    ) -> ProcessorJob | None:
        """Cancel recovery only while no reversal may have reached the processor."""
        if not reason.strip():
            raise ValueError("cancellation reason must not be empty")
        row = self._session.scalar(
            select(ProcessorJobModel)
            .where(
                ProcessorJobModel.transaction_id == transaction_id,
                ProcessorJobModel.operation_type
                == ProcessorOperationType.REVERSE.value,
                ProcessorJobModel.state.in_(
                    (ProcessorJobState.READY.value, ProcessorJobState.RETRY.value)
                ),
            )
            .with_for_update()
        )
        if row is None:
            return None

        validate_processor_job_transition(
            ProcessorJobState(row.state), ProcessorJobState.CANCELLED
        )
        row.state = ProcessorJobState.CANCELLED.value
        row.result = reason
        row.completed_at = cancelled_at
        row.updated_at = cancelled_at
        row.last_error_code = None
        row.last_error_detail_sanitized = None
        self._session.flush()
        return _to_domain(row)

    def claim_next_due_reverse(
        self,
        *,
        worker_id: str,
        claim_token: UUID,
        claimed_at: datetime,
    ) -> ProcessorJob | None:
        """Claim one due reversal job without competing with other workers.

        The caller owns the surrounding database transaction and must commit it
        before making the processor request.  PostgreSQL keeps the row lock
        until that commit, while ``SKIP LOCKED`` lets another worker continue
        looking for a different ready job instead of waiting.
        """
        row = self._session.scalar(
            select(ProcessorJobModel)
            .where(
                ProcessorJobModel.operation_type
                == ProcessorOperationType.REVERSE.value,
                ProcessorJobModel.state.in_(
                    (ProcessorJobState.READY.value, ProcessorJobState.RETRY.value)
                ),
                ProcessorJobModel.next_attempt_at <= claimed_at,
            )
            .order_by(ProcessorJobModel.next_attempt_at, ProcessorJobModel.id)
            .with_for_update(skip_locked=True)
        )
        if row is None:
            return None

        validate_processor_job_transition(
            ProcessorJobState(row.state), ProcessorJobState.PROCESSING
        )
        row.state = ProcessorJobState.PROCESSING.value
        row.worker_id = worker_id
        row.claim_token = claim_token
        row.processing_started_at = claimed_at
        row.attempt_count += 1
        row.updated_at = claimed_at
        self._session.flush()
        return _to_domain(row)

    def move_next_stale_processing_to_manual_review(
        self,
        *,
        processing_started_before: datetime,
        reviewed_at: datetime,
    ) -> ProcessorJob | None:
        """Stop one abandoned job without making another processor request.

        The caller owns the transaction.  ``SKIP LOCKED`` lets concurrent
        watchdog instances inspect other work instead of blocking on a job
        whose original worker may be finishing at the same time.
        """
        row = self._session.scalar(
            select(ProcessorJobModel)
            .where(
                ProcessorJobModel.state == ProcessorJobState.PROCESSING.value,
                ProcessorJobModel.processing_started_at <= processing_started_before,
            )
            .order_by(ProcessorJobModel.processing_started_at, ProcessorJobModel.id)
            .with_for_update(skip_locked=True)
        )
        if row is None:
            return None

        validate_processor_job_transition(
            ProcessorJobState(row.state), ProcessorJobState.MANUAL_REVIEW
        )
        row.state = ProcessorJobState.MANUAL_REVIEW.value
        row.updated_at = reviewed_at
        row.last_error_code = "PROCESSING_TIMEOUT"
        row.last_error_detail_sanitized = None
        self._session.flush()
        return _to_domain(row)

    def finalize_claim(
        self,
        *,
        job_id: int,
        claim_token: UUID,
        target: ProcessorJobState,
        finalized_at: datetime,
        next_attempt_at: datetime | None = None,
        result: str | None = None,
        last_error_code: str | None = None,
        last_error_detail_sanitized: str | None = None,
    ) -> bool:
        """Persist one claimed outcome only while its claim is still current."""
        validate_processor_job_transition(ProcessorJobState.PROCESSING, target)
        if target is ProcessorJobState.RETRY and next_attempt_at is None:
            raise ValueError("RETRY requires next_attempt_at")
        if target in {ProcessorJobState.COMPLETED, ProcessorJobState.CANCELLED} and (
            result is None
        ):
            raise ValueError(f"{target.value} requires result")

        values: dict[str, object] = {
            "state": target.value,
            "updated_at": finalized_at,
            "last_error_code": last_error_code,
            "last_error_detail_sanitized": last_error_detail_sanitized,
        }
        if next_attempt_at is not None:
            values["next_attempt_at"] = next_attempt_at
        if result is not None:
            values["result"] = result
        if target in {ProcessorJobState.COMPLETED, ProcessorJobState.CANCELLED}:
            values["completed_at"] = finalized_at

        outcome = self._session.execute(
            update(ProcessorJobModel)
            .where(
                ProcessorJobModel.id == job_id,
                ProcessorJobModel.state == ProcessorJobState.PROCESSING.value,
                ProcessorJobModel.claim_token == claim_token,
            )
            .values(**values)
            .returning(ProcessorJobModel.id)
        )
        return outcome.scalar_one_or_none() is not None

    def transition(
        self,
        *,
        job_id: int,
        target: ProcessorJobState,
        next_attempt_at: datetime | None = None,
        worker_id: str | None = None,
        claim_token: UUID | None = None,
        processing_started_at: datetime | None = None,
        result: str | None = None,
        completed_at: datetime | None = None,
        last_error_code: str | None = None,
        last_error_detail_sanitized: str | None = None,
    ) -> ProcessorJob | None:
        row = self._session.get(ProcessorJobModel, job_id)
        if row is None:
            return None

        validate_processor_job_transition(ProcessorJobState(row.state), target)
        if target is ProcessorJobState.PROCESSING and (
            worker_id is None or claim_token is None or processing_started_at is None
        ):
            raise ValueError(
                "PROCESSING requires worker_id, claim_token and start time"
            )
        if target is ProcessorJobState.RETRY and next_attempt_at is None:
            raise ValueError("RETRY requires next_attempt_at")
        if target in {ProcessorJobState.COMPLETED, ProcessorJobState.CANCELLED} and (
            result is None or completed_at is None
        ):
            raise ValueError(f"{target.value} requires result and completed_at")

        row.state = target.value
        row.updated_at = datetime.now(UTC)
        if next_attempt_at is not None:
            row.next_attempt_at = next_attempt_at
        if worker_id is not None:
            row.worker_id = worker_id
        if claim_token is not None:
            row.claim_token = claim_token
        if processing_started_at is not None:
            row.processing_started_at = processing_started_at
        if result is not None:
            row.result = result
        if completed_at is not None:
            row.completed_at = completed_at
        row.last_error_code = last_error_code
        row.last_error_detail_sanitized = last_error_detail_sanitized
        self._session.flush()
        return _to_domain(row)

    def recovery_state_aggregates(self) -> list[RecoveryStateAggregate]:
        """Count jobs by state, with age, attempts and resolution time."""
        resolution_seconds = func.extract(
            "epoch",
            ProcessorJobModel.completed_at - ProcessorJobModel.created_at,
        )
        rows = self._session.execute(
            select(
                ProcessorJobModel.state,
                func.count(),
                func.min(ProcessorJobModel.created_at),
                func.max(ProcessorJobModel.attempt_count),
                func.max(resolution_seconds),
            ).group_by(ProcessorJobModel.state)
        ).all()
        return [
            RecoveryStateAggregate(
                state=str(state),
                job_count=int(count),
                oldest_created_at=oldest_created_at,
                max_attempt_count=(
                    0 if max_attempt_count is None else int(max_attempt_count)
                ),
                max_resolution_seconds=(
                    None if max_resolution is None else float(max_resolution)
                ),
            )
            for (
                state,
                count,
                oldest_created_at,
                max_attempt_count,
                max_resolution,
            ) in rows
        ]
