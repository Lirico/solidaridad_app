"""Sanitized operational events for durable recovery alerts."""

import logging

import httpx

logger = logging.getLogger(__name__)


def log_recovery_alert_opened(
    *,
    processor_job_id: int,
    transaction_number: str,
    cause: str,
    webhook_url: str = "",
    webhook_timeout_seconds: float = 2.0,
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
    post_recovery_alert(
        url=webhook_url,
        timeout_seconds=webhook_timeout_seconds,
        processor_job_id=processor_job_id,
        transaction_number=transaction_number,
        cause=cause,
    )


def post_recovery_alert(
    *,
    url: str,
    timeout_seconds: float,
    processor_job_id: int,
    transaction_number: str,
    cause: str,
) -> None:
    """Notify an optional webhook. A failed POST does not undo the alert."""
    if not url.strip():
        return
    payload = {
        "processor_job_id": processor_job_id,
        "transaction_number": transaction_number,
        "cause": cause,
        "alert_state": "OPEN",
    }
    try:
        response = httpx.post(url, json=payload, timeout=timeout_seconds)
        response.raise_for_status()
    except Exception:
        logger.warning(
            "recovery_alert_webhook_failed",
            extra={
                "event_name": "recovery_alert_webhook_failed",
                "processor_job_id": processor_job_id,
                "transaction_number": transaction_number,
                "cause": cause,
            },
        )
