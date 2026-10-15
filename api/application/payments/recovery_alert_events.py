"""Sanitized operational events for durable recovery alerts."""

import logging

logger = logging.getLogger(__name__)


def log_recovery_alert_opened(
    *,
    processor_job_id: int,
    transaction_number: str,
    cause: str,
) -> None:
    """Emit identifiers needed by operations, excluding payment credentials."""
    logger.warning(
        "recovery_alert_opened",
        extra={
            "event_name": "recovery_alert_opened",
            "processor_job_id": processor_job_id,
            "transaction_number": transaction_number,
            "cause": cause,
            "alert_state": "OPEN",
        },
    )
