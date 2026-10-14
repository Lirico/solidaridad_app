"""Retrieve one terminal-scoped transaction in its public form."""

from dataclasses import dataclass

from application.payments.public_transaction_status import (
    PublicTransactionStatus,
    project_public_transaction_status,
)
from domain.exceptions import TransactionNotFound
from domain.processor_job import ProcessorOperationType
from domain.transaction import Transaction
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.transaction_repository import TransactionRepository


@dataclass(frozen=True, slots=True)
class GetTransactionStatusResult:
    transaction: Transaction
    public_status: PublicTransactionStatus


class GetTransactionStatus:
    """Look up a transaction without disclosing another terminal's data."""

    def __init__(
        self,
        transactions: TransactionRepository,
        jobs: ProcessorJobRepository,
    ) -> None:
        self._transactions = transactions
        self._jobs = jobs

    def execute(
        self,
        *,
        terminal_id: str,
        transaction_number: str,
    ) -> GetTransactionStatusResult:
        transaction = self._transactions.get_by_transaction_number(
            transaction_number=transaction_number,
            terminal_id=terminal_id,
        )
        if transaction is None:
            raise TransactionNotFound()

        reverse_job = self._jobs.get_by_transaction(
            transaction_id=transaction.id,
            operation_type=ProcessorOperationType.REVERSE,
        )
        return GetTransactionStatusResult(
            transaction=transaction,
            public_status=project_public_transaction_status(transaction, reverse_job),
        )
