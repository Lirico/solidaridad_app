"""Durable processor job entities and state transitions."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID


class ProcessorOperationType(StrEnum):
    AUTHORIZE = "AUTHORIZE"
    REVERSE = "REVERSE"


class ProcessorJobState(StrEnum):
    READY = "READY"
    PROCESSING = "PROCESSING"
    RETRY = "RETRY"
    COMPLETED = "COMPLETED"
    MANUAL_REVIEW = "MANUAL_REVIEW"


class InvalidProcessorJobTransition(ValueError):
    """Raised when a job state change is not part of the state machine."""


_ALLOWED_TRANSITIONS: dict[ProcessorJobState, frozenset[ProcessorJobState]] = {
    ProcessorJobState.READY: frozenset(
        {ProcessorJobState.PROCESSING, ProcessorJobState.MANUAL_REVIEW}
    ),
    ProcessorJobState.PROCESSING: frozenset(
        {
            ProcessorJobState.RETRY,
            ProcessorJobState.COMPLETED,
            ProcessorJobState.MANUAL_REVIEW,
        }
    ),
    ProcessorJobState.RETRY: frozenset(
        {ProcessorJobState.PROCESSING, ProcessorJobState.MANUAL_REVIEW}
    ),
    ProcessorJobState.COMPLETED: frozenset(),
    ProcessorJobState.MANUAL_REVIEW: frozenset(
        {ProcessorJobState.RETRY, ProcessorJobState.COMPLETED}
    ),
}


def validate_processor_job_transition(
    current: ProcessorJobState,
    target: ProcessorJobState,
) -> None:
    if target not in _ALLOWED_TRANSITIONS[current]:
        raise InvalidProcessorJobTransition(
            f"processor job cannot transition from {current.value} to {target.value}"
        )


@dataclass(frozen=True, slots=True)
class ProcessorJob:
    id: int
    transaction_id: int
    operation_type: ProcessorOperationType
    state: ProcessorJobState
    result: str | None
    attempt_count: int
    next_attempt_at: datetime
    worker_id: str | None
    claim_token: UUID | None
    processing_started_at: datetime | None
    original_stan: str | None
    original_ticket: str | None
    reversal_stan: str | None
    last_error_code: str | None
    last_error_detail_sanitized: str | None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None

