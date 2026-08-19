"""Transaction persistence repository."""

from datetime import UTC, date, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from domain.transaction_status_event import (
    TransactionStatusActorType,
    TransactionStatusEventType,
)
from persistence.models.transaction import Transaction as TransactionModel
from persistence.models.transaction import TransactionNumberCounter
from persistence.models.transaction_status_event import TransactionStatusEvent


def ticket_from_transaction_number(transaction_number: str) -> str:
    """Extract numeric DE62 ticket from OP-YYMMDD-NNNNNNNN."""
    return transaction_number.rsplit("-", 1)[-1]


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
        processor_ticket=row.processor_ticket,
        void_idempotency_key=row.void_idempotency_key,
    )


class TransactionRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def _append_status_event(
        self,
        *,
        transaction_id: int,
        from_status: str | None,
        to_status: str,
        event_type: TransactionStatusEventType,
        actor_type: TransactionStatusActorType,
        actor_user_id: int | None = None,
        processor_response_code: str | None = None,
        user_message: str | None = None,
        idempotency_key: str | None = None,
    ) -> None:
        self._session.add(
            TransactionStatusEvent(
                transaction_id=transaction_id,
                from_status=from_status,
                to_status=to_status,
                event_type=event_type.value,
                actor_type=actor_type.value,
                actor_user_id=actor_user_id,
                processor_response_code=processor_response_code,
                user_message=user_message,
                idempotency_key=idempotency_key,
                created_at=datetime.now(UTC),
            )
        )

    def get_by_idempotency(
        self,
        *,
        user_id: int,
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

    def get_by_transaction_number(
        self,
        *,
        transaction_number: str,
        terminal_id: str,
    ) -> Transaction | None:
        stmt = select(TransactionModel).where(
            TransactionModel.transaction_number == transaction_number,
            TransactionModel.terminal_id == terminal_id,
        )
        row = self._session.scalars(stmt).first()
        if row is None:
            return None
        return _to_domain(row)

    def next_transaction_number(self, business_date: date) -> str:
        """Atomically allocate OP-YYMMDD-NNNNNNNN for the business date.

        Sequence is zero-padded to at least 8 digits and grows beyond that
        without truncating if daily volume ever exceeds 99_999_999.
        """
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

        counter.last_value += 1
        self._session.flush()
        return f"OP-{business_date.strftime('%y%m%d')}-{counter.last_value:08d}"

    def create_pending(
        self,
        *,
        transaction_number: str,
        user_id: int,
        installation_id: int,
        terminal_id: str,
        product: Product,
        processor_product_code: str,
        amount_minor: int,
        card_last4: str,
        stan: str,
        processor_ticket: str,
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
            processor_ticket=processor_ticket,
            user_message=user_message,
            idempotency_key=idempotency_key,
            request_fingerprint=request_fingerprint,
            created_at=now,
            updated_at=now,
        )
        self._session.add(row)
        self._session.flush()
        self._append_status_event(
            transaction_id=row.id,
            from_status=None,
            to_status=TransactionStatus.PENDING.value,
            event_type=TransactionStatusEventType.CREATED,
            actor_type=TransactionStatusActorType.USER,
            actor_user_id=user_id,
            user_message=user_message,
            idempotency_key=idempotency_key,
        )
        self._session.flush()
        return _to_domain(row)

    def list_by_terminal_id(
        self,
        *,
        terminal_id: str,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Transaction], int]:
        """Return transactions for a terminal, newest first, plus total count."""
        stmt = (
            select(TransactionModel)
            .where(TransactionModel.terminal_id == terminal_id)
            .order_by(TransactionModel.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        rows = list(self._session.scalars(stmt).all())

        count_stmt = (
            select(func.count())
            .select_from(TransactionModel)
            .where(
                TransactionModel.terminal_id == terminal_id,
            )
        )
        total = self._session.scalar(count_stmt) or 0

        return [_to_domain(r) for r in rows], total

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
        from_status = row.status
        row.status = status.value
        row.user_message = user_message
        row.processor_response_code = processor_response_code
        row.auth_id = auth_id
        row.retrieval_reference = retrieval_reference
        row.updated_at = datetime.now(UTC)
        self._append_status_event(
            transaction_id=row.id,
            from_status=from_status,
            to_status=status.value,
            event_type=TransactionStatusEventType.GATEWAY_RESULT,
            actor_type=TransactionStatusActorType.SYSTEM,
            actor_user_id=row.user_id,
            processor_response_code=processor_response_code,
            user_message=user_message,
            idempotency_key=row.idempotency_key,
        )
        self._session.flush()
        return _to_domain(row)

    def apply_void_result(
        self,
        *,
        transaction_id: int,
        status: TransactionStatus,
        void_idempotency_key: str,
        user_message: str | None = None,
        processor_response_code: str | None = None,
    ) -> Transaction:
        row = self._session.get(TransactionModel, transaction_id)
        if row is None:
            raise LookupError(f"transaction {transaction_id} not found")
        from_status = row.status
        row.status = status.value
        row.void_idempotency_key = void_idempotency_key
        if user_message is not None:
            row.user_message = user_message
        if processor_response_code is not None:
            row.processor_response_code = processor_response_code
        row.updated_at = datetime.now(UTC)
        self._append_status_event(
            transaction_id=row.id,
            from_status=from_status,
            to_status=status.value,
            event_type=TransactionStatusEventType.VOID_RESULT,
            actor_type=TransactionStatusActorType.USER,
            actor_user_id=row.user_id,
            processor_response_code=processor_response_code,
            user_message=user_message if user_message is not None else row.user_message,
            idempotency_key=void_idempotency_key,
        )
        self._session.flush()
        return _to_domain(row)

    def record_idempotent_hit(
        self,
        *,
        transaction_id: int,
        status: TransactionStatus,
        actor_user_id: int,
        idempotency_key: str | None = None,
        user_message: str | None = None,
        processor_response_code: str | None = None,
    ) -> None:
        """Record a replay that did not change transaction status."""
        status_value = status.value
        self._append_status_event(
            transaction_id=transaction_id,
            from_status=status_value,
            to_status=status_value,
            event_type=TransactionStatusEventType.IDEMPOTENT_HIT,
            actor_type=TransactionStatusActorType.USER,
            actor_user_id=actor_user_id,
            processor_response_code=processor_response_code,
            user_message=user_message,
            idempotency_key=idempotency_key,
        )
        self._session.flush()
