"""Prometheus exposition for recovery work, without payment credentials."""

from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from domain.processor_job import ProcessorJobState
from persistence.database import SessionLocal
from persistence.models.processor_job import ProcessorJob


@dataclass(frozen=True, slots=True)
class RecoveryJobMetric:
    state: ProcessorJobState
    count: int
    oldest_created_at: datetime | None
    max_attempt_count: int


@dataclass(frozen=True, slots=True)
class RecoveryResolutionMetric:
    count: int
    seconds_total: float


class RecoveryMetricsExporter:
    """Read aggregate recovery metrics in a short-lived, read-only session."""

    def __init__(
        self,
        *,
        session_factory: Callable[[], Session] = SessionLocal,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
        open_job_alert_age_seconds: float = 300.0,
    ) -> None:
        if open_job_alert_age_seconds <= 0:
            raise ValueError("open_job_alert_age_seconds must be positive")
        self._session_factory = session_factory
        self._now = now
        self._open_job_alert_age_seconds = open_job_alert_age_seconds

    def render(self) -> str:
        session = self._session_factory()
        try:
            jobs = self._jobs_by_state(session)
            resolution = self._resolution(session)
            return self._render(jobs, resolution)
        finally:
            session.rollback()
            session.close()

    def _jobs_by_state(self, session: Session) -> list[RecoveryJobMetric]:
        rows = session.execute(
            select(
                ProcessorJob.state,
                func.count(ProcessorJob.id),
                func.min(ProcessorJob.created_at),
                func.max(ProcessorJob.attempt_count),
            ).group_by(ProcessorJob.state)
        ).all()
        return [
            RecoveryJobMetric(
                state=ProcessorJobState(state),
                count=count,
                oldest_created_at=oldest_created_at,
                max_attempt_count=max_attempt_count,
            )
            for state, count, oldest_created_at, max_attempt_count in rows
        ]

    @staticmethod
    def _resolution(session: Session) -> RecoveryResolutionMetric:
        resolution_seconds = func.extract(
            "epoch", ProcessorJob.completed_at - ProcessorJob.created_at
        )
        count, seconds_total = session.execute(
            select(
                func.count(ProcessorJob.id),
                func.coalesce(func.sum(resolution_seconds), 0),
            ).where(ProcessorJob.completed_at.is_not(None))
        ).one()
        return RecoveryResolutionMetric(
            count=count,
            seconds_total=float(seconds_total),
        )

    def _render(
        self,
        jobs: list[RecoveryJobMetric],
        resolution: RecoveryResolutionMetric,
    ) -> str:
        now = self._now()
        by_state = {metric.state: metric for metric in jobs}
        lines = [
            "# HELP solidaridad_recovery_jobs "
            "Number of durable recovery jobs by state.",
            "# TYPE solidaridad_recovery_jobs gauge",
        ]
        for state in ProcessorJobState:
            metric = by_state.get(state)
            count = metric.count if metric is not None else 0
            lines.append(f'solidaridad_recovery_jobs{{state="{state.value}"}} {count}')

        lines.extend(
            [
                "# HELP solidaridad_recovery_oldest_job_age_seconds "
                "Age of the oldest job by state.",
                "# TYPE solidaridad_recovery_oldest_job_age_seconds gauge",
                "# HELP solidaridad_recovery_max_attempts "
                "Highest attempt count by state.",
                "# TYPE solidaridad_recovery_max_attempts gauge",
                "# HELP solidaridad_recovery_open_job_alert_age_threshold_seconds "
                "Configured alert threshold for an open recovery job.",
                "# TYPE solidaridad_recovery_open_job_alert_age_threshold_seconds "
                "gauge",
                "solidaridad_recovery_open_job_alert_age_threshold_seconds "
                f"{self._open_job_alert_age_seconds}",
            ]
        )
        for state in ProcessorJobState:
            metric = by_state.get(state)
            age = (
                max(0.0, (now - metric.oldest_created_at).total_seconds())
                if metric is not None and metric.oldest_created_at is not None
                else 0.0
            )
            attempts = metric.max_attempt_count if metric is not None else 0
            lines.append(
                "solidaridad_recovery_oldest_job_age_seconds"
                f'{{state="{state.value}"}} {age}'
            )
            lines.append(
                f'solidaridad_recovery_max_attempts{{state="{state.value}"}} {attempts}'
            )

        lines.extend(
            [
                "# HELP solidaridad_recovery_resolution_seconds_total "
                "Total time to resolution for completed recovery jobs.",
                "# TYPE solidaridad_recovery_resolution_seconds_total counter",
                "solidaridad_recovery_resolution_seconds_total "
                f"{resolution.seconds_total}",
                "# HELP solidaridad_recovery_resolutions_total "
                "Number of completed recovery jobs.",
                "# TYPE solidaridad_recovery_resolutions_total counter",
                f"solidaridad_recovery_resolutions_total {resolution.count}",
            ]
        )
        return "\n".join(lines) + "\n"
