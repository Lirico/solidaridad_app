"""Detect processor jobs whose worker stopped making progress."""

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from persistence.repositories.payment_processing_config_repository import (
    PaymentProcessingConfigRepository,
)
from persistence.repositories.processor_job_repository import ProcessorJobRepository


class StaleProcessingJobMonitor:
    """Move at most one abandoned job to manual review per invocation."""

    def __init__(
        self,
        *,
        session: Session,
        jobs: ProcessorJobRepository,
        configs: PaymentProcessingConfigRepository,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._session = session
        self._jobs = jobs
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
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        return job is not None
