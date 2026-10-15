"""Append-only persistence for central operator recovery actions."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.recovery_review import (
    ManualRecoveryResolution,
    RecoveryReviewAction,
    RecoveryReviewActionType,
)
from persistence.models.recovery_review_action import (
    RecoveryReviewAction as RecoveryReviewActionModel,
)


def _to_domain(row: RecoveryReviewActionModel) -> RecoveryReviewAction:
    return RecoveryReviewAction(
        id=row.id,
        processor_job_id=row.processor_job_id,
        operator_user_id=row.operator_user_id,
        action_type=RecoveryReviewActionType(row.action_type),
        resolution=(
            ManualRecoveryResolution(row.resolution)
            if row.resolution is not None
            else None
        ),
        reason=row.reason,
        external_reference=row.external_reference,
        created_at=row.created_at,
    )


class RecoveryReviewActionRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def record(
        self,
        *,
        processor_job_id: int,
        operator_user_id: int,
        action_type: RecoveryReviewActionType,
        reason: str,
        resolution: ManualRecoveryResolution | None = None,
        external_reference: str | None = None,
    ) -> None:
        self._session.add(
            RecoveryReviewActionModel(
                processor_job_id=processor_job_id,
                operator_user_id=operator_user_id,
                action_type=action_type.value,
                resolution=resolution.value if resolution is not None else None,
                reason=reason,
                external_reference=external_reference,
            )
        )
        self._session.flush()

    def list_for_job(self, *, processor_job_id: int) -> list[RecoveryReviewAction]:
        rows = self._session.scalars(
            select(RecoveryReviewActionModel)
            .where(RecoveryReviewActionModel.processor_job_id == processor_job_id)
            .order_by(
                RecoveryReviewActionModel.created_at.asc(),
                RecoveryReviewActionModel.id.asc(),
            )
        ).all()
        return [_to_domain(row) for row in rows]
