"""Close the current administrative batch for one terminal."""

from dataclasses import dataclass

from sqlalchemy.orm import Session

from domain.batch_close import BatchClose
from domain.exceptions import (
    BatchCloseHasInFlightTransactions,
    BatchIsEmpty,
    MissingIdempotencyKey,
)
from domain.transaction import Transaction
from persistence.repositories.transaction_repository import TransactionRepository


@dataclass(frozen=True, slots=True)
class CloseBatchResult:
    batch_close: BatchClose
    transactions: list[Transaction]


class CloseBatch:
    def __init__(self, session: Session, transactions: TransactionRepository) -> None:
        self._session = session
        self._transactions = transactions

    def execute(
        self,
        *,
        installation_id: str,
        user_id: int,
        idempotency_key: str | None,
    ) -> CloseBatchResult:
        if idempotency_key is None or not idempotency_key.strip():
            raise MissingIdempotencyKey()

        result = self._transactions.close_current_batch(
            terminal_id=installation_id,
            closed_by_user_id=user_id,
            idempotency_key=idempotency_key.strip(),
        )
        if result is None:
            raise BatchIsEmpty()
        if isinstance(result, str):
            raise BatchCloseHasInFlightTransactions()

        batch_close, transactions = result
        self._session.commit()
        return CloseBatchResult(
            batch_close=batch_close,
            transactions=transactions,
        )
