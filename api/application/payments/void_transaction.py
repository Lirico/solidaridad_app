"""Void (anulación) an approved payment transaction."""

import secrets
from dataclasses import dataclass
from enum import IntEnum

from sqlalchemy.orm import Session

from application.payments.ports import (
    AuthorizeResult,
    GatewayOutcome,
    PaymentGateway,
    VoidRequest,
)
from application.payments.response_messages import (
    MSG_VOID_DECLINED,
    MSG_VOID_FAILED,
    MSG_VOID_UNKNOWN,
    MSG_VOIDED,
    message_for_code,
)
from domain.exceptions import (
    CardMismatch,
    InvalidCardNumber,
    MissingIdempotencyKey,
    TransactionNotFound,
    TransactionNotVoidable,
)
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.repositories.transaction_repository import (
    TransactionRepository,
    ticket_from_transaction_number,
)


class VoidTransactionHttpStatus(IntEnum):
    OK = 200


@dataclass(frozen=True, slots=True)
class VoidTransactionResult:
    transaction: Transaction
    http_status: VoidTransactionHttpStatus
    user_message: str


def _validate_pan(card_number: str) -> str:
    pan = card_number.replace(" ", "").strip()
    if not pan.isdigit() or not (13 <= len(pan) <= 19):
        raise InvalidCardNumber()
    return pan


class VoidTransaction:
    def __init__(
        self,
        session: Session,
        transactions: TransactionRepository,
        gateway: PaymentGateway,
    ) -> None:
        self._session = session
        self._transactions = transactions
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
        card_last4 = pan[-4:]
        exp = expiration_date.strip() if expiration_date else None
        if exp == "":
            exp = None

        tx = self._transactions.get_by_transaction_number(
            transaction_number=transaction_number,
            terminal_id=terminal_id[:8],
        )
        if tx is None:
            raise TransactionNotFound()

        if tx.status == TransactionStatus.VOIDED:
            self._record_idempotent_hit(tx, key)
            return VoidTransactionResult(
                transaction=tx,
                http_status=VoidTransactionHttpStatus.OK,
                user_message=tx.user_message or MSG_VOIDED,
            )

        if tx.status != TransactionStatus.APPROVED:
            raise TransactionNotVoidable()

        if tx.void_idempotency_key is not None and tx.void_idempotency_key == key:
            self._record_idempotent_hit(tx, key)
            return VoidTransactionResult(
                transaction=tx,
                http_status=VoidTransactionHttpStatus.OK,
                user_message=tx.user_message or MSG_VOID_DECLINED,
            )

        if tx.card_last4 != card_last4:
            raise CardMismatch()

        original_ticket = tx.processor_ticket or ticket_from_transaction_number(
            tx.transaction_number
        )
        void_stan = f"{secrets.randbelow(1_000_000):06d}"

        gateway_result = self._gateway.void(
            VoidRequest(
                product_code=tx.processor_product_code,
                amount_minor=tx.amount_minor,
                card_number=pan,
                terminal_id=tx.terminal_id[:8].ljust(8),
                stan=void_stan,
                original_ticket=original_ticket,
                void_ticket=void_stan,
                expiration_date=exp,
            )
        )
        final, message = self._apply_gateway_result(tx.id, key, gateway_result)
        self._session.commit()
        return VoidTransactionResult(
            transaction=final,
            http_status=VoidTransactionHttpStatus.OK,
            user_message=message,
        )

    def _record_idempotent_hit(self, tx: Transaction, idempotency_key: str) -> None:
        self._transactions.record_idempotent_hit(
            transaction_id=tx.id,
            status=tx.status,
            actor_user_id=tx.user_id,
            idempotency_key=idempotency_key,
            user_message=tx.user_message,
            processor_response_code=tx.processor_response_code,
        )
        self._session.commit()

    def _apply_gateway_result(
        self,
        transaction_id: int,
        void_idempotency_key: str,
        result: AuthorizeResult,
    ) -> tuple[Transaction, str]:
        if result.outcome == GatewayOutcome.APPROVED:
            status = TransactionStatus.VOIDED
            message = message_for_code(result.response_code, approved=True)
            if message == "Pago aprobado":
                message = MSG_VOIDED
            final = self._transactions.apply_void_result(
                transaction_id=transaction_id,
                status=status,
                user_message=message,
                void_idempotency_key=void_idempotency_key,
                processor_response_code=result.response_code,
            )
            return final, message

        if result.outcome == GatewayOutcome.DECLINED:
            message = MSG_VOID_DECLINED
            if result.response_code:
                message = message_for_code(result.response_code, approved=False)
            final = self._transactions.apply_void_result(
                transaction_id=transaction_id,
                status=TransactionStatus.APPROVED,
                void_idempotency_key=void_idempotency_key,
                processor_response_code=result.response_code,
            )
            return final, message

        if result.outcome == GatewayOutcome.FAILED:
            message = MSG_VOID_FAILED
            final = self._transactions.apply_void_result(
                transaction_id=transaction_id,
                status=TransactionStatus.APPROVED,
                void_idempotency_key=void_idempotency_key,
                processor_response_code=result.response_code,
            )
            return final, message

        message = MSG_VOID_UNKNOWN
        final = self._transactions.apply_void_result(
            transaction_id=transaction_id,
            status=TransactionStatus.UNKNOWN,
            user_message=message,
            void_idempotency_key=void_idempotency_key,
            processor_response_code=result.response_code,
        )
        return final, message
