"""Central-operator consultation and resolution of recovery cases."""

from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from application.payments.response_messages import MSG_DECLINED_DEFAULT, MSG_FAILED
from config import Settings
from domain.exceptions import (
    ManualRecoveryCaseNotFound,
    ManualRecoveryConflict,
    ManualReversalRetryDisabled,
)
from domain.processor_job import ProcessorJob, ProcessorJobState
from domain.recovery_alert import RecoveryAlert
from domain.recovery_review import (
    ManualRecoveryResolution,
    RecoveryReviewAction,
    RecoveryReviewActionType,
)
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.recovery_alert_repository import RecoveryAlertRepository
from persistence.repositories.recovery_review_action_repository import (
    RecoveryReviewActionRepository,
)
from persistence.repositories.transaction_repository import TransactionRepository


@dataclass(frozen=True, slots=True)
class ManualRecoveryCase:
    job: ProcessorJob
    transaction: Transaction
    alerts: list[RecoveryAlert]
    actions: list[RecoveryReviewAction]


class ReviewManualRecovery:
    """Keep central decisions, their audit evidence, and public state atomic."""

    def __init__(
        self,
        *,
        session: Session,
        transactions: TransactionRepository,
        jobs: ProcessorJobRepository,
        alerts: RecoveryAlertRepository,
        actions: RecoveryReviewActionRepository,
        settings: Settings,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._session = session
        self._transactions = transactions
        self._jobs = jobs
        self._alerts = alerts
        self._actions = actions
        self._manual_retry_enabled = settings.manual_reversal_retry_enabled
        self._now = now

    def list_cases(self) -> list[ManualRecoveryCase]:
        return [self._case_for(job) for job in self._jobs.list_manual_review()]

    def get_case(self, *, job_id: int) -> ManualRecoveryCase:
        job = self._jobs.get_by_id(job_id)
        if job is None:
            raise ManualRecoveryCaseNotFound()
        return self._case_for(job)

    def resolve(
        self,
        *,
        job_id: int,
        operator_user_id: int,
        resolution: ManualRecoveryResolution,
        reason: str,
        external_reference: str | None,
    ) -> ManualRecoveryCase:
        reviewed_at = self._now()
        try:
            job = self._locked_manual_review_job(job_id)
            target_status, user_message = _resolution_projection(resolution)
            transaction = self._transactions.get_by_id_for_update(
                transaction_id=job.transaction_id
            )
            self._jobs.complete_manual_review(
                job_id=job.id,
                result=resolution.value,
                completed_at=reviewed_at,
            )
            updated_transaction = self._transactions.apply_manual_recovery_resolution(
                transaction_id=transaction.id,
                status=target_status,
                operator_user_id=operator_user_id,
                user_message=user_message,
            )
            self._actions.record(
                processor_job_id=job.id,
                operator_user_id=operator_user_id,
                action_type=RecoveryReviewActionType.RESOLUTION,
                resolution=resolution,
                reason=reason.strip(),
                external_reference=_normalize_reference(external_reference),
            )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        completed = self._jobs.get_by_id(job_id)
        if completed is None:
            raise RuntimeError("resolved processor job disappeared")
        return ManualRecoveryCase(
            job=completed,
            transaction=updated_transaction,
            alerts=self._alerts.list_for_job(processor_job_id=job_id),
            actions=self._actions.list_for_job(processor_job_id=job_id),
        )

    def retry(
        self,
        *,
        job_id: int,
        operator_user_id: int,
        reason: str,
        external_reference: str | None,
    ) -> ManualRecoveryCase:
        if not self._manual_retry_enabled:
            raise ManualReversalRetryDisabled()
        retried_at = self._now()
        try:
            job = self._locked_manual_review_job(job_id)
            transaction = self._transactions.get_by_id_for_update(
                transaction_id=job.transaction_id
            )
            self._jobs.retry_manual_review(
                job_id=job.id,
                next_attempt_at=retried_at,
            )
            self._transactions.record_manual_recovery_retry(
                transaction_id=transaction.id,
                operator_user_id=operator_user_id,
            )
            self._actions.record(
                processor_job_id=job.id,
                operator_user_id=operator_user_id,
                action_type=RecoveryReviewActionType.MANUAL_RETRY,
                reason=reason.strip(),
                external_reference=_normalize_reference(external_reference),
            )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        return self.get_case(job_id=job_id)

    def _locked_manual_review_job(self, job_id: int) -> ProcessorJob:
        job = self._jobs.get_by_id_for_update(job_id)
        if job is None:
            raise ManualRecoveryCaseNotFound()
        if job.state is not ProcessorJobState.MANUAL_REVIEW:
            raise ManualRecoveryConflict()
        return job

    def _case_for(self, job: ProcessorJob) -> ManualRecoveryCase:
        transaction = self._transactions.get_by_id(transaction_id=job.transaction_id)
        if transaction is None:
            raise RuntimeError(f"processor job {job.id} has no transaction")
        return ManualRecoveryCase(
            job=job,
            transaction=transaction,
            alerts=self._alerts.list_for_job(processor_job_id=job.id),
            actions=self._actions.list_for_job(processor_job_id=job.id),
        )


def _resolution_projection(
    resolution: ManualRecoveryResolution,
) -> tuple[TransactionStatus, str]:
    if resolution is ManualRecoveryResolution.REVERSED_CONFIRMED:
        return TransactionStatus.FAILED, MSG_FAILED
    if resolution is ManualRecoveryResolution.PROCESSOR_DECLINED:
        return TransactionStatus.DECLINED, MSG_DECLINED_DEFAULT
    return TransactionStatus.APPROVED, "Pago aprobado"


def _normalize_reference(value: str | None) -> str | None:
    normalized = value.strip() if value is not None else ""
    return normalized or None
