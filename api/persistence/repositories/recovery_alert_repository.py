"""Persistence for operational recovery alerts."""

from datetime import datetime

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from domain.recovery_alert import RecoveryAlertState
from persistence.models.recovery_alert import RecoveryAlert


class RecoveryAlertRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def open_for_job(
        self,
        *,
        processor_job_id: int,
        cause: str,
        opened_at: datetime,
    ) -> bool:
        """Open an alert once for a job and cause, even across replicas."""
        outcome = self._session.execute(
            insert(RecoveryAlert)
            .values(
                processor_job_id=processor_job_id,
                cause=cause,
                state=RecoveryAlertState.OPEN.value,
                opened_at=opened_at,
            )
            .on_conflict_do_nothing(
                constraint="uq_recovery_alerts_job_cause"
            )
            .returning(RecoveryAlert.id)
        )
        return outcome.scalar_one_or_none() is not None
