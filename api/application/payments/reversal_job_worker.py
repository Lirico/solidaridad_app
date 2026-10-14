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
        configs: PaymentProcessingConfigRepository,
        gateway: PaymentGateway,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
        random_value: Callable[[], float] = random.random,
        claim_token_factory: Callable[[], UUID] = uuid4,
    ) -> None:
        if not worker_id.strip():
            raise ValueError("worker_id must not be empty")
        self._worker_id = worker_id
        self._session = session
        self._transactions = transactions
        self._jobs = jobs
        self._configs = configs
        self._gateway = gateway
        self._now = now
        self._random_value = random_value
        self._claim_token_factory = claim_token_factory

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
                error_code="RECOVERY_DATA_MISSING",
            )
            return True

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
            else:
                self._session.rollback()
            return True

        if (
            result.outcome is ReversalOutcome.NOT_SENT
            and claimed.attempt_count < policy.max_attempts
        ):
            self._persist_retry(claimed, policy, finalized_at)
            return True

        self._persist_manual_review(
            claimed,
            error_code=result.outcome.value,
            error_detail=result.response_code,
            finalized_at=finalized_at,
        )
        return True

    def _claim(self) -> ProcessorJob | None:
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
        else:
            self._session.rollback()

    def _persist_manual_review(
        self,
        claimed: ProcessorJob,
        *,
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
            self._commit_outcome()
        else:
            self._session.rollback()

    def _commit_outcome(self) -> None:
        try:
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
