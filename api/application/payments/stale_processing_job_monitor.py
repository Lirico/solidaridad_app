"""Detect processor jobs whose worker stopped making progress."""

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from application.payments.recovery_alert_events import log_recovery_alert_opened
from persistence.repositories.payment_processing_config_repository import (
    PaymentProcessingConfigRepository,
)
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.recovery_alert_repository import RecoveryAlertRepository


class StaleProcessingJobMonitor:
    """Move at most one abandoned job to manual review per invocation."""

    def __init__(
        self,
        *,
        session: Session,
        jobs: ProcessorJobRepository,
        alerts: RecoveryAlertRepository,
        configs: PaymentProcessingConfigRepository,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._session = session
        self._jobs = jobs
        self._alerts = alerts
        self._configs = configs
        self._now = now

    def run_once(self) -> bool:
        """Quarantine one timed-out job and return whether one was found."""
        observed_at = self._now()
        try:
            timeout_seconds = self._configs.get_default().processing_timeout_seconds
            job = self._jobs.move_next_stale_processing_to_manual_review(
                processing_started_before=(
                    observed_at - timedelta(seconds=timeout_seconds)
                ),
                reviewed_at=observed_at,
            )
            alert_opened = job is not None and self._alerts.open_for_job(
                processor_job_id=job.id,
                cause="PROCESSING_TIMEOUT",
                opened_at=observed_at,
            )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        if job is not None and alert_opened:
            log_recovery_alert_opened(
                processor_job_id=job.id,
                transaction_id=job.transaction_id,
                cause="PROCESSING_TIMEOUT",
            )
        return job is not None
