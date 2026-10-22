"""Retrieve the latest durable void operation for an authenticated terminal."""

from dataclasses import dataclass

from domain.exceptions import TransactionNotFound, VoidOperationNotFound
from domain.transaction import Transaction
from domain.void_operation import VoidOperation
from persistence.repositories.transaction_repository import TransactionRepository
from persistence.repositories.void_operation_repository import VoidOperationRepository


@dataclass(frozen=True, slots=True)
class GetVoidOperationResult:
    transaction: Transaction
    void_operation: VoidOperation


class GetVoidOperation:
    def __init__(
        self,
        transactions: TransactionRepository,
        void_operations: VoidOperationRepository,
    ) -> None:
        self._transactions = transactions
        self._void_operations = void_operations

    def execute(
        self, *, terminal_id: str, transaction_number: str
    ) -> GetVoidOperationResult:
        transaction = self._transactions.get_by_transaction_number(
            transaction_number=transaction_number,
            terminal_id=terminal_id,
        )
        if transaction is None:
            raise TransactionNotFound()
        operation = self._void_operations.get_latest_for_transaction(
            transaction_id=transaction.id
        )
        if operation is None:
            raise VoidOperationNotFound()
        return GetVoidOperationResult(transaction=transaction, void_operation=operation)
