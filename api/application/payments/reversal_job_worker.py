"""Single deterministic iteration of the durable reversal worker."""

import random
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy.orm import Session

from application.payments.ports import (
    PaymentGateway,
    ReversalOutcome,
    ReverseRequest,
)
from application.payments.recovery_alert_events import log_recovery_alert_opened
from application.payments.recovery_job_events import log_recovery_job_transition
from application.payments.response_messages import MSG_FAILED
from application.payments.reversal_retry import ReversalRetryPolicy
from domain.authorization_outcome import AuthorizationOutcome
from domain.processor_job import ProcessorJob, ProcessorJobState
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.repositories.payment_processing_config_repository import (
    PaymentProcessingConfigRepository,
)
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.recovery_alert_repository import RecoveryAlertRepository
from persistence.repositories.transaction_repository import TransactionRepository


class ReversalJobWorker:
    """Claim and process at most one durable reversal job per invocation."""

    def __init__(
        self,
        *,
        worker_id: str,
        session: Session,
        transactions: TransactionRepository,
        jobs: ProcessorJobRepository,
        alerts: RecoveryAlertRepository,
        configs: PaymentProcessingConfigRepository,
        gateway: PaymentGateway,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
        random_value: Callable[[], float] = random.random,
        claim_token_factory: Callable[[], UUID] = uuid4,
        should_stop: Callable[[], bool] = lambda: False,
    ) -> None:
        if not worker_id.strip():
            raise ValueError("worker_id must not be empty")
        self._worker_id = worker_id
        self._session = session
        self._transactions = transactions
        self._jobs = jobs
        self._alerts = alerts
        self._configs = configs
        self._gateway = gateway
        self._now = now
        self._random_value = random_value
        self._claim_token_factory = claim_token_factory
        self._should_stop = should_stop

    def run_once(self) -> bool:
        """Process one job, returning whether this worker claimed any work."""
        claimed = self._claim()
        if claimed is None:
            return False

        transaction = self._transactions.get_by_id(
            transaction_id=claimed.transaction_id
        )
        request = self._reverse_request(claimed, transaction)
        if request is None:
            self._persist_manual_review(
                claimed,
                transaction_number=(
                    transaction.transaction_number if transaction is not None else None
                ),
                error_code="RECOVERY_DATA_MISSING",
            )
            return True
        if transaction is None:
            raise RuntimeError("recovery transaction missing after validation")

        policy = ReversalRetryPolicy.from_config(
            self._configs.get_default(),
            random_value=self._random_value,
        )
        result = self._gateway.reverse(request)
        finalized_at = self._now()

        if result.outcome is ReversalOutcome.REVERSED_CONFIRMED:
            if self._jobs.finalize_claim(
                job_id=claimed.id,
                claim_token=self._claim_token(claimed),
                target=ProcessorJobState.COMPLETED,
                finalized_at=finalized_at,
                result=result.outcome.value,
            ):
                self._transactions.update_result(
                    transaction_id=claimed.transaction_id,
                    status=TransactionStatus.FAILED,
                    authorization_outcome=AuthorizationOutcome.INDETERMINATE,
                    user_message=MSG_FAILED,
                    processor_response_code=result.response_code,
                )
                self._commit_outcome()
                log_recovery_job_transition(
                    transaction_number=transaction.transaction_number,
                    processor_job_id=claimed.id,
                    state=ProcessorJobState.COMPLETED,
                )
            else:
                self._session.rollback()
            return True

        if (
            result.outcome is ReversalOutcome.NOT_SENT
            and claimed.attempt_count < policy.max_attempts
        ):
            self._persist_retry(
                claimed,
                transaction.transaction_number,
                policy,
                finalized_at,
            )
            return True

        self._persist_manual_review(
            claimed,
            transaction_number=transaction.transaction_number,
            error_code=result.outcome.value,
            error_detail=result.response_code,
            finalized_at=finalized_at,
        )
        return True

    def _claim(self) -> ProcessorJob | None:
        if self._should_stop():
            return None
        try:
            claimed = self._jobs.claim_next_due_reverse(
                worker_id=self._worker_id,
                claim_token=self._claim_token_factory(),
                claimed_at=self._now(),
            )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        return claimed

    @staticmethod
    def _reverse_request(
        claimed: ProcessorJob,
        transaction: Transaction | None,
    ) -> ReverseRequest | None:
        if (
            transaction is None
            or transaction.card_number is None
            or transaction.expiration_date is None
            or claimed.original_stan is None
            or claimed.original_ticket is None
            or claimed.reversal_stan is None
        ):
            return None
        return ReverseRequest(
            product_code=transaction.processor_product_code,
            amount_minor=transaction.amount_minor,
            card_number=transaction.card_number,
            expiration_date=transaction.expiration_date,
            terminal_id=transaction.terminal_id[:8].ljust(8),
            original_stan=claimed.original_stan,
            original_ticket=claimed.original_ticket,
            reversal_stan=claimed.reversal_stan,
        )

    @staticmethod
    def _claim_token(claimed: ProcessorJob) -> UUID:
        if claimed.claim_token is None:
            raise RuntimeError("claimed job has no claim token")
        return claimed.claim_token

    def _persist_retry(
        self,
        claimed: ProcessorJob,
        transaction_number: str,
        policy: ReversalRetryPolicy,
        finalized_at: datetime,
    ) -> None:
        retry_at = finalized_at + timedelta(
            seconds=policy.delay_after_attempt(claimed.attempt_count)
        )
        if self._jobs.finalize_claim(
            job_id=claimed.id,
            claim_token=self._claim_token(claimed),
            target=ProcessorJobState.RETRY,
            finalized_at=finalized_at,
            next_attempt_at=retry_at,
            last_error_code=ReversalOutcome.NOT_SENT.value,
        ):
            self._commit_outcome()
            log_recovery_job_transition(
                transaction_number=transaction_number,
                processor_job_id=claimed.id,
                state=ProcessorJobState.RETRY,
                error_code=ReversalOutcome.NOT_SENT.value,
            )
        else:
            self._session.rollback()

    def _persist_manual_review(
        self,
        claimed: ProcessorJob,
        *,
        transaction_number: str | None,
        error_code: str,
        error_detail: str | None = None,
        finalized_at: datetime | None = None,
    ) -> None:
        if self._jobs.finalize_claim(
            job_id=claimed.id,
            claim_token=self._claim_token(claimed),
            target=ProcessorJobState.MANUAL_REVIEW,
            finalized_at=finalized_at or self._now(),
            last_error_code=error_code,
            last_error_detail_sanitized=error_detail,
        ):
            alert_opened = self._alerts.open_for_job(
                processor_job_id=claimed.id,
                cause=error_code,
                opened_at=finalized_at or self._now(),
            )
            self._commit_outcome()
            resolved_transaction_number = transaction_number or "unknown"
            log_recovery_job_transition(
                transaction_number=resolved_transaction_number,
                processor_job_id=claimed.id,
                state=ProcessorJobState.MANUAL_REVIEW,
                error_code=error_code,
            )
            if alert_opened:
                log_recovery_alert_opened(
                    processor_job_id=claimed.id,
                    transaction_number=resolved_transaction_number,
                    cause=error_code,
                )
        else:
            self._session.rollback()

    def _commit_outcome(self) -> None:
        try:
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
