"""List transactions for a terminal (paginated)."""

from dataclasses import dataclass

from domain.transaction import Transaction
from persistence.repositories.transaction_repository import TransactionRepository


@dataclass(frozen=True, slots=True)
class ListTransactionsResult:
    transactions: list[Transaction]
    total: int


class ListTransactions:
    def __init__(self, transactions: TransactionRepository) -> None:
        self._transactions = transactions

    def execute(
        self,
        *,
        terminal_id: str,
        limit: int = 20,
        offset: int = 0,
    ) -> ListTransactionsResult:
        items, total = self._transactions.list_by_terminal_id(
            terminal_id=terminal_id,
            limit=limit,
            offset=offset,
        )
        return ListTransactionsResult(transactions=items, total=total)
