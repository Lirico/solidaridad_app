"""Conservatively recover authorization requests stranded while PENDING."""

import secrets
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from application.payments.response_messages import MSG_UNKNOWN
from domain.authorization_outcome import AuthorizationOutcome
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.transaction_repository import TransactionRepository


class EnqueueStalePendingReversals:
    """Create the one durable reverse job for old, unclassified PENDING rows.

    This is deliberately an explicit one-shot watchdog.  RA-11 will decide
    how and when it is scheduled; it is safe to invoke from multiple replicas
    because candidate transactions are locked with ``SKIP LOCKED`` and the job
    identity is unique in the database.
    """

    def __init__(
        self,
        *,
        session: Session,
        transactions: TransactionRepository,
        jobs: ProcessorJobRepository,
        stale_after: timedelta,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        if stale_after <= timedelta(0):
            raise ValueError("stale_after must be positive")
        self._session = session
        self._transactions = transactions
        self._jobs = jobs
        self._stale_after = stale_after
        self._now = now

    def execute(self) -> list[Transaction]:
        now = self._now()
        candidates = self._transactions.list_stale_pending_without_reverse_job(
            created_before=now - self._stale_after
        )
        recovered: list[Transaction] = []
        try:
            for transaction in candidates:
                if transaction.stan is None or transaction.processor_ticket is None:
                    continue
                self._transactions.update_result(
                    transaction_id=transaction.id,
                    status=TransactionStatus.PENDING,
                    authorization_outcome=AuthorizationOutcome.INDETERMINATE,
                    user_message=MSG_UNKNOWN,
                )
                self._jobs.create_reverse(
                    transaction_id=transaction.id,
                    original_stan=transaction.stan,
                    original_ticket=transaction.processor_ticket,
                    reversal_stan=f"{secrets.randbelow(1_000_000):06d}",
                    next_attempt_at=now,
                )
                self._transactions.record_reversal_enqueued(
                    transaction_id=transaction.id
                )
                recovered.append(transaction)
            if recovered:
                self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        return recovered
