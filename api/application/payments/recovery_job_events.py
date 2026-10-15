"""Structured, credential-free recovery lifecycle events."""

import logging

from domain.processor_job import ProcessorJobState

logger = logging.getLogger(__name__)


def log_recovery_job_transition(
    *,
    transaction_number: str,
    processor_job_id: int,
    state: ProcessorJobState,
    error_code: str | None = None,
) -> None:
    """Log only operational identifiers and sanitized processor codes."""
    logger.info(
        "recovery_job_transition",
        extra={
            "event_name": "recovery_job_transition",
            "transaction_number": transaction_number,
            "processor_job_id": processor_job_id,
            "job_state": state.value,
            "error_code": error_code,
        },
    )
