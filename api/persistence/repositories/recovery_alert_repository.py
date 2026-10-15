"""Persistence for operational recovery alerts."""

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from domain.recovery_alert import RecoveryAlert, RecoveryAlertState
from persistence.models.recovery_alert import RecoveryAlert as RecoveryAlertModel


def _to_domain(row: RecoveryAlertModel) -> RecoveryAlert:
    return RecoveryAlert(
        id=row.id,
        processor_job_id=row.processor_job_id,
        cause=row.cause,
        state=RecoveryAlertState(row.state),
        opened_at=row.opened_at,
        created_at=row.created_at,
    )


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
            insert(RecoveryAlertModel)
            .values(
                processor_job_id=processor_job_id,
                cause=cause,
                state=RecoveryAlertState.OPEN.value,
                opened_at=opened_at,
            )
            .on_conflict_do_nothing(
                constraint="uq_recovery_alerts_job_cause"
            )
            .returning(RecoveryAlertModel.id)
        )
        return outcome.scalar_one_or_none() is not None

    def list_for_job(self, *, processor_job_id: int) -> list[RecoveryAlert]:
        rows = self._session.scalars(
            select(RecoveryAlertModel)
            .where(RecoveryAlertModel.processor_job_id == processor_job_id)
            .order_by(RecoveryAlertModel.opened_at.asc(), RecoveryAlertModel.id.asc())
        ).all()
        return [_to_domain(row) for row in rows]
