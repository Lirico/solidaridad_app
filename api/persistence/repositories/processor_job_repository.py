"""Persistence operations for durable processor jobs."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
    validate_processor_job_transition,
)
from persistence.models.processor_job import ProcessorJob as ProcessorJobModel


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
            worker_id is None
            or claim_token is None
            or processing_started_at is None
        ):
            raise ValueError(
                "PROCESSING requires worker_id, claim_token and start time"
            )
        if target is ProcessorJobState.RETRY and next_attempt_at is None:
            raise ValueError("RETRY requires next_attempt_at")
        if target is ProcessorJobState.COMPLETED and (
            result is None or completed_at is None
        ):
            raise ValueError("COMPLETED requires result and completed_at")

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
