"""Load one transaction for the terminal that owns it."""

from domain.exceptions import TransactionNotFound
from domain.transaction import Transaction
from persistence.repositories.transaction_repository import TransactionRepository


class GetTransaction:
    def __init__(self, transactions: TransactionRepository) -> None:
        self._transactions = transactions

    def execute(
        self,
        *,
        terminal_id: str,
        transaction_number: str,
    ) -> Transaction:
        tx = self._transactions.get_by_transaction_number(
            transaction_number=transaction_number,
            terminal_id=terminal_id[:8],
        )
        if tx is None:
            raise TransactionNotFound()
        return tx
