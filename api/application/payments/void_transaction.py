"""Void an approved payment without losing ambiguity about the void itself."""

import hashlib
import secrets
from dataclasses import dataclass
from enum import IntEnum

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from application.payments.ports import (
    GatewayOutcome,
    PaymentGateway,
    VoidRequest,
    VoidResult,
)
from application.payments.response_messages import (
    MSG_APPROVED,
    MSG_VOID_DECLINED,
    MSG_VOID_FAILED,
    MSG_VOID_UNDER_REVIEW,
    MSG_VOIDED,
    message_for_code,
)
from domain.exceptions import (
    CardMismatch,
    IdempotencyConflict,
    InvalidCardNumber,
    MissingIdempotencyKey,
    TransactionBatchClosed,
    TransactionNotFound,
    TransactionNotVoidable,
)
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from domain.void_operation import (
    VoidOperation,
    VoidOperationOutcome,
    VoidOperationStatus,
)
from persistence.repositories.transaction_repository import (
    TransactionRepository,
    ticket_from_transaction_number,
)
from persistence.repositories.void_operation_repository import VoidOperationRepository


class VoidTransactionHttpStatus(IntEnum):
    OK = 200


@dataclass(frozen=True, slots=True)
class VoidTransactionResult:
    transaction: Transaction
    void_operation: VoidOperation | None
    http_status: VoidTransactionHttpStatus
    user_message: str


def _validate_pan(card_number: str) -> str:
    pan = card_number.replace(" ", "").strip()
    if not pan.isdigit() or not (13 <= len(pan) <= 19):
        raise InvalidCardNumber()
    return pan


def _fingerprint(*, card_number: str, expiration_date: str | None) -> str:
    return hashlib.sha256(f"{card_number}|{expiration_date or ''}".encode()).hexdigest()


class VoidTransaction:
    def __init__(
        self,
        session: Session,
        transactions: TransactionRepository,
        void_operations: VoidOperationRepository,
        gateway: PaymentGateway,
    ) -> None:
        self._session = session
        self._transactions = transactions
        self._void_operations = void_operations
        self._gateway = gateway

    def execute(
        self,
        *,
        terminal_id: str,
        transaction_number: str,
        idempotency_key: str | None,
        card_number: str,
        expiration_date: str | None = None,
    ) -> VoidTransactionResult:
        if idempotency_key is None or not idempotency_key.strip():
            raise MissingIdempotencyKey()
        key = idempotency_key.strip()
        pan = _validate_pan(card_number)
        exp = expiration_date.strip() if expiration_date else None
        if exp == "":
            exp = None
        fingerprint = _fingerprint(card_number=pan, expiration_date=exp)
        transaction = self._transactions.get_by_transaction_number(
            transaction_number=transaction_number, terminal_id=terminal_id[:8]
        )
        if transaction is None:
            raise TransactionNotFound()
        if transaction.batch_close_id is not None:
            raise TransactionBatchClosed()
        if transaction.status == TransactionStatus.VOIDED:
            self._record_idempotent_hit(transaction, key)
            return VoidTransactionResult(
                transaction,
                None,
                VoidTransactionHttpStatus.OK,
                transaction.user_message or MSG_VOIDED,
            )
        if transaction.status != TransactionStatus.APPROVED:
            raise TransactionNotVoidable()
        if transaction.card_last4 != pan[-4:]:
            raise CardMismatch()
        existing = self._void_operations.get_by_idempotency(
            transaction_id=transaction.id, idempotency_key=key
        )
        if existing is not None:
            return self._replay(transaction, existing, fingerprint)
        active = self._void_operations.get_active_for_transaction(
            transaction_id=transaction.id
        )
        if active is not None:
            raise TransactionNotVoidable(
                "La anulación anterior sigue en verificación con casa central"
            )

        original_ticket = (
            transaction.processor_ticket
            or ticket_from_transaction_number(transaction.transaction_number)
        )
        stan = f"{secrets.randbelow(1_000_000):06d}"
        try:
            operation = self._void_operations.create_pending(
                transaction_id=transaction.id,
                idempotency_key=key,
                request_fingerprint=fingerprint,
                stan=stan,
                void_ticket=stan,
                original_ticket=original_ticket,
                user_message="Anulación en curso",
            )
            # Persist the identifiers before the external ISO effect. If the
            # process dies now, replay escalates conservatively to review.
            self._session.commit()
        except IntegrityError:
            self._session.rollback()
            raced = self._void_operations.get_by_idempotency(
                transaction_id=transaction.id, idempotency_key=key
            )
            if raced is None:
                raise
            return self._replay(transaction, raced, fingerprint)

        try:
            result = self._gateway.void(
                VoidRequest(
                    product_code=transaction.processor_product_code,
                    amount_minor=transaction.amount_minor,
                    card_number=pan,
                    terminal_id=transaction.terminal_id[:8].ljust(8),
                    stan=operation.stan,
                    original_ticket=operation.original_ticket,
                    void_ticket=operation.void_ticket,
                    expiration_date=exp,
                )
            )
        except Exception:
            self._mark_under_review(operation)
            raise
        return self._apply_gateway_result(transaction, operation, key, result)

    def _replay(
        self, transaction: Transaction, operation: VoidOperation, fingerprint: str
    ) -> VoidTransactionResult:
        if operation.request_fingerprint != fingerprint:
            raise IdempotencyConflict()
        if operation.status == VoidOperationStatus.PENDING:
            operation = self._mark_under_review(operation)
        self._record_idempotent_hit(transaction, operation.idempotency_key)
        return self._result(transaction, operation)

    def _apply_gateway_result(
        self,
        transaction: Transaction,
        operation: VoidOperation,
        idempotency_key: str,
        result: VoidResult,
    ) -> VoidTransactionResult:
        if result.outcome == GatewayOutcome.APPROVED:
            message = message_for_code(result.response_code, approved=True)
            if message == MSG_APPROVED:
                message = MSG_VOIDED
            final_transaction = self._transactions.apply_void_result(
                transaction_id=transaction.id,
                status=TransactionStatus.VOIDED,
                user_message=message,
                void_idempotency_key=idempotency_key,
                processor_response_code=result.response_code,
            )
            final_operation = self._void_operations.apply_result(
                void_operation_id=operation.id,
                outcome=VoidOperationOutcome.APPROVED,
                status=VoidOperationStatus.VOIDED,
                user_message=message,
                processor_response_code=result.response_code,
            )
        elif result.outcome == GatewayOutcome.DECLINED:
            message = (
                message_for_code(result.response_code, approved=False)
                if result.response_code
                else MSG_VOID_DECLINED
            )
            final_transaction = self._transactions.apply_void_result(
                transaction_id=transaction.id,
                status=TransactionStatus.APPROVED,
                void_idempotency_key=idempotency_key,
                processor_response_code=result.response_code,
            )
            final_operation = self._void_operations.apply_result(
                void_operation_id=operation.id,
                outcome=VoidOperationOutcome.DECLINED,
                status=VoidOperationStatus.DECLINED,
                user_message=message,
                processor_response_code=result.response_code,
            )
        elif result.outcome == GatewayOutcome.FAILED:
            final_transaction = self._transactions.apply_void_result(
                transaction_id=transaction.id,
                status=TransactionStatus.APPROVED,
                void_idempotency_key=idempotency_key,
                processor_response_code=result.response_code,
            )
            final_operation = self._void_operations.apply_result(
                void_operation_id=operation.id,
                outcome=VoidOperationOutcome.NOT_SENT,
                status=VoidOperationStatus.FAILED,
                user_message=MSG_VOID_FAILED,
                processor_response_code=result.response_code,
            )
        else:
            final_transaction = transaction
            final_operation = self._mark_under_review(
                operation, response_code=result.response_code
            )

        self._session.commit()
        return self._result(final_transaction, final_operation)

    def _mark_under_review(
        self, operation: VoidOperation, *, response_code: str | None = None
    ) -> VoidOperation:
        updated = self._void_operations.apply_result(
            void_operation_id=operation.id,
            outcome=VoidOperationOutcome.INDETERMINATE,
            status=VoidOperationStatus.UNDER_REVIEW,
            user_message=MSG_VOID_UNDER_REVIEW,
            processor_response_code=response_code,
        )
        self._void_operations.open_alert_once(
            void_operation_id=updated.id, cause="VOID_INDETERMINATE"
        )
        self._session.commit()
        return updated

    def _record_idempotent_hit(self, transaction: Transaction, key: str) -> None:
        self._transactions.record_idempotent_hit(
            transaction_id=transaction.id,
            status=transaction.status,
            actor_user_id=transaction.user_id,
            idempotency_key=key,
            user_message=transaction.user_message,
            processor_response_code=transaction.processor_response_code,
        )
        self._session.commit()

    def _result(
        self, transaction: Transaction, operation: VoidOperation
    ) -> VoidTransactionResult:
        return VoidTransactionResult(
            transaction=transaction,
            void_operation=operation,
            # UNDER_REVIEW is a final result of this request. It requires
            # central-office work, but the terminal must not poll or treat the
            # request as asynchronously accepted.
            http_status=VoidTransactionHttpStatus.OK,
            user_message=operation.user_message,
        )
