"""Persistence for durable void operations and their manual-review alerts."""

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from domain.void_operation import (
    VoidOperation,
    VoidOperationOutcome,
    VoidOperationStatus,
)
from persistence.models.void_operation import VoidOperation as VoidOperationModel
from persistence.models.void_operation import VoidOperationAlert


def _to_domain(row: VoidOperationModel) -> VoidOperation:
    return VoidOperation(
        id=row.id,
        transaction_id=row.transaction_id,
        idempotency_key=row.idempotency_key,
        request_fingerprint=row.request_fingerprint,
        stan=row.stan,
        void_ticket=row.void_ticket,
        original_ticket=row.original_ticket,
        outcome=VoidOperationOutcome(row.outcome),
        status=VoidOperationStatus(row.status),
        processor_response_code=row.processor_response_code,
        user_message=row.user_message,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


class VoidOperationRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_idempotency(
        self, *, transaction_id: int, idempotency_key: str
    ) -> VoidOperation | None:
        row = self._session.scalar(
            select(VoidOperationModel).where(
                VoidOperationModel.transaction_id == transaction_id,
                VoidOperationModel.idempotency_key == idempotency_key,
            )
        )
        return _to_domain(row) if row is not None else None

    def get_active_for_transaction(
        self, *, transaction_id: int
    ) -> VoidOperation | None:
        row = self._session.scalar(
            select(VoidOperationModel).where(
                VoidOperationModel.transaction_id == transaction_id,
                VoidOperationModel.status.in_(
                    (
                        VoidOperationStatus.PENDING.value,
                        VoidOperationStatus.UNDER_REVIEW.value,
                    )
                ),
            )
        )
        return _to_domain(row) if row is not None else None

    def get_latest_for_transaction(
        self, *, transaction_id: int
    ) -> VoidOperation | None:
        row = self._session.scalar(
            select(VoidOperationModel)
            .where(VoidOperationModel.transaction_id == transaction_id)
            .order_by(
                VoidOperationModel.created_at.desc(), VoidOperationModel.id.desc()
            )
            .limit(1)
        )
        return _to_domain(row) if row is not None else None

    def create_pending(
        self,
        *,
        transaction_id: int,
        idempotency_key: str,
        request_fingerprint: str,
        stan: str,
        void_ticket: str,
        original_ticket: str,
        user_message: str,
    ) -> VoidOperation:
        now = datetime.now(UTC)
        row = VoidOperationModel(
            transaction_id=transaction_id,
            idempotency_key=idempotency_key,
            request_fingerprint=request_fingerprint,
            stan=stan,
            void_ticket=void_ticket,
            original_ticket=original_ticket,
            outcome=VoidOperationOutcome.PENDING.value,
            status=VoidOperationStatus.PENDING.value,
            user_message=user_message,
            created_at=now,
            updated_at=now,
        )
        self._session.add(row)
        self._session.flush()
        return _to_domain(row)

    def apply_result(
        self,
        *,
        void_operation_id: int,
        outcome: VoidOperationOutcome,
        status: VoidOperationStatus,
        user_message: str,
        processor_response_code: str | None,
    ) -> VoidOperation:
        row = self._session.get(VoidOperationModel, void_operation_id)
        if row is None:
            raise LookupError(f"void operation {void_operation_id} not found")
        row.outcome = outcome.value
        row.status = status.value
        row.user_message = user_message
        row.processor_response_code = processor_response_code
        row.updated_at = datetime.now(UTC)
        self._session.flush()
        return _to_domain(row)

    def open_alert_once(self, *, void_operation_id: int, cause: str) -> bool:
        outcome = self._session.execute(
            insert(VoidOperationAlert)
            .values(
                void_operation_id=void_operation_id,
                cause=cause,
                state="OPEN",
                opened_at=datetime.now(UTC),
            )
            .on_conflict_do_nothing(
                constraint="uq_void_operation_alerts_operation_cause"
            )
            .returning(VoidOperationAlert.id)
        )
        return outcome.scalar_one_or_none() is not None
