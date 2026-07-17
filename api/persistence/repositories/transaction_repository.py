"""Transaction persistence repository."""

from datetime import UTC, date, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.exceptions import TransactionNumberExhausted
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.models.transaction import Transaction as TransactionModel
from persistence.models.transaction import TransactionNumberCounter


def _to_domain(row: TransactionModel) -> Transaction:
    return Transaction(
        id=row.id,
        transaction_number=row.transaction_number,
        user_id=row.user_id,
        installation_id=row.installation_id,
        terminal_id=row.terminal_id,
        product=Product(row.product),
        processor_product_code=row.processor_product_code,
        amount_minor=row.amount_minor,
        status=TransactionStatus(row.status),
        card_last4=row.card_last4,
        stan=row.stan,
        auth_id=row.auth_id,
        retrieval_reference=row.retrieval_reference,
        processor_response_code=row.processor_response_code,
        user_message=row.user_message,
        idempotency_key=row.idempotency_key,
        request_fingerprint=row.request_fingerprint,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


class TransactionRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_idempotency(
        self,
        *,
        user_id: UUID,
        idempotency_key: str,
    ) -> Transaction | None:
        stmt = select(TransactionModel).where(
            TransactionModel.user_id == user_id,
            TransactionModel.idempotency_key == idempotency_key,
        )
        row = self._session.scalars(stmt).first()
        if row is None:
            return None
        return _to_domain(row)

    def next_transaction_number(self, business_date: date) -> str:
        """Atomically allocate OP-YYMMDD-NNNN for the business date."""
        stmt = (
            select(TransactionNumberCounter)
            .where(TransactionNumberCounter.business_date == business_date)
            .with_for_update()
        )
        counter = self._session.scalars(stmt).first()
        if counter is None:
            counter = TransactionNumberCounter(
                business_date=business_date,
                last_value=0,
            )
            self._session.add(counter)
            self._session.flush()
            # Re-lock in case of concurrent insert race
            counter = self._session.scalars(stmt).one()

        if counter.last_value >= 9999:
            raise TransactionNumberExhausted()

        counter.last_value += 1
        self._session.flush()
        return f"OP-{business_date.strftime('%y%m%d')}-{counter.last_value:04d}"

    def create_pending(
        self,
        *,
        transaction_number: str,
        user_id: UUID,
        installation_id: str,
        terminal_id: str,
        product: Product,
        processor_product_code: str,
        amount_minor: int,
        card_last4: str,
        stan: str,
        idempotency_key: str,
        request_fingerprint: str,
        user_message: str,
    ) -> Transaction:
        now = datetime.now(UTC)
        row = TransactionModel(
            transaction_number=transaction_number,
            user_id=user_id,
            installation_id=installation_id,
            terminal_id=terminal_id,
            product=product.value,
            processor_product_code=processor_product_code,
            amount_minor=amount_minor,
            status=TransactionStatus.PENDING.value,
            card_last4=card_last4,
            stan=stan,
            user_message=user_message,
            idempotency_key=idempotency_key,
            request_fingerprint=request_fingerprint,
            created_at=now,
            updated_at=now,
        )
        self._session.add(row)
        self._session.flush()
        return _to_domain(row)

    def update_result(
        self,
        *,
        transaction_id: int,
        status: TransactionStatus,
        user_message: str,
        processor_response_code: str | None = None,
        auth_id: str | None = None,
        retrieval_reference: str | None = None,
    ) -> Transaction:
        row = self._session.get(TransactionModel, transaction_id)
        if row is None:
            raise LookupError(f"transaction {transaction_id} not found")
        row.status = status.value
        row.user_message = user_message
        row.processor_response_code = processor_response_code
        row.auth_id = auth_id
        row.retrieval_reference = retrieval_reference
        row.updated_at = datetime.now(UTC)
        self._session.flush()
        return _to_domain(row)
