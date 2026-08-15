"""Create and authorize a payment transaction."""

import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime
from enum import IntEnum

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from application.payments.ports import (
    AuthorizeRequest,
    AuthorizeResult,
    GatewayOutcome,
    PaymentGateway,
)
from application.payments.response_messages import (
    MSG_FAILED,
    MSG_PENDING,
    MSG_UNKNOWN,
    message_for_code,
)
from domain.exceptions import (
    IdempotencyConflict,
    InvalidCardNumber,
    InvalidCvv,
    MissingIdempotencyKey,
    MissingTerminalId,
)
from domain.money import Money, parse_amount
from domain.product import Product, parse_product, processor_product_code
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.repositories.installation_repository import InstallationRepository
from persistence.repositories.transaction_repository import (
    TransactionRepository,
    ticket_from_transaction_number,
)


class CreateTransactionHttpStatus(IntEnum):
    CREATED = 201
    ACCEPTED = 202


@dataclass(frozen=True, slots=True)
class CreateTransactionResult:
    transaction: Transaction
    http_status: CreateTransactionHttpStatus


def _fingerprint(
    *,
    product: Product,
    amount_minor: int,
    card_last4: str,
    expiration_date: str | None,
) -> str:
    raw = "|".join(
        [
            product.value,
            str(amount_minor),
            card_last4,
            expiration_date or "",
        ]
    )
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _validate_cvv(cvv: str) -> str:
    cleaned = cvv.strip()
    if not cleaned.isdigit() or len(cleaned) not in (3, 4):
        raise InvalidCvv()
    return cleaned


def _validate_pan(card_number: str) -> str:
    pan = card_number.replace(" ", "").strip()
    if not pan.isdigit() or not (13 <= len(pan) <= 19):
        raise InvalidCardNumber()
    return pan


class CreateTransaction:
    def __init__(
        self,
        session: Session,
        transactions: TransactionRepository,
        installations: InstallationRepository,
        gateway: PaymentGateway,
    ) -> None:
        self._session = session
        self._transactions = transactions
        self._installations = installations
        self._gateway = gateway

    def execute(
        self,
        *,
        user_id: int,
        installation_id: str,
        idempotency_key: str | None,
        product: str,
        amount: str,
        card_number: str,
        cvv: str | None = None,
        expiration_date: str | None = None,
        entry_mode: str = "012",
        track2: str | None = None,
    ) -> CreateTransactionResult:

        if idempotency_key is None or not idempotency_key.strip():
            raise MissingIdempotencyKey()
        key = idempotency_key.strip()

        parsed_product = parse_product(product)
        money: Money = parse_amount(amount)
        pan = _validate_pan(card_number)
        # La banda magnética (entry_mode 022) no contiene CVV: se omite la
        # validación en ese modo. El gateway/procesador no usan CVV.
        if entry_mode != "022":
            _validate_cvv(cvv or "")
        card_last4 = pan[-4:]


        exp = expiration_date.strip() if expiration_date else None
        if exp == "":
            exp = None
        fingerprint = _fingerprint(
            product=parsed_product,
            amount_minor=money.amount_minor,
            card_last4=card_last4,
            expiration_date=exp,
        )

        existing = self._transactions.get_by_idempotency(
            user_id=user_id,
            idempotency_key=key,
        )
        if existing is not None:
            return self._replay(existing, fingerprint, idempotency_key=key)

        installation = self._installations.get_by_installation_id(installation_id)
        if installation is None:
            raise MissingTerminalId()
        terminal_id = installation.installation_id.strip()
        if not terminal_id:
            raise MissingTerminalId()

        business_date = datetime.now(UTC).date()
        transaction_number = self._transactions.next_transaction_number(business_date)
        processor_ticket = ticket_from_transaction_number(transaction_number)
        stan = f"{secrets.randbelow(1_000_000):06d}"
        proc_code = processor_product_code(parsed_product)

        try:
            pending = self._transactions.create_pending(
                transaction_number=transaction_number,
                user_id=user_id,
                installation_id=installation.id,
                terminal_id=terminal_id[:8],
                product=parsed_product,
                processor_product_code=proc_code,
                amount_minor=money.amount_minor,
                card_last4=card_last4,
                stan=stan,
                processor_ticket=processor_ticket,
                idempotency_key=key,
                request_fingerprint=fingerprint,
                user_message=MSG_PENDING,
            )
            self._session.commit()
        except IntegrityError:
            self._session.rollback()
            raced = self._transactions.get_by_idempotency(
                user_id=user_id,
                idempotency_key=key,
            )
            if raced is None:
                raise
            return self._replay(raced, fingerprint, idempotency_key=key)

        gateway_result = self._gateway.authorize(
            AuthorizeRequest(
                product_code=proc_code,
                amount_minor=money.amount_minor,
                card_number=pan,
                terminal_id=terminal_id[:8].ljust(8),
                stan=stan,
                ticket_number=processor_ticket,
                expiration_date=exp,
                entry_mode=entry_mode,
                track2=track2,
            )
        )
        final = self._apply_gateway_result(pending.id, gateway_result)
        self._session.commit()
        return CreateTransactionResult(
            transaction=final,
            http_status=CreateTransactionHttpStatus.CREATED,
        )

    def _replay(
        self,
        existing: Transaction,
        fingerprint: str,
        *,
        idempotency_key: str,
    ) -> CreateTransactionResult:
        if existing.request_fingerprint != fingerprint:
            raise IdempotencyConflict()
        self._transactions.record_idempotent_hit(
            transaction_id=existing.id,
            status=existing.status,
            actor_user_id=existing.user_id,
            idempotency_key=idempotency_key,
            user_message=existing.user_message,
            processor_response_code=existing.processor_response_code,
        )
        self._session.commit()
        if existing.status == TransactionStatus.PENDING:
            return CreateTransactionResult(
                transaction=existing,
                http_status=CreateTransactionHttpStatus.ACCEPTED,
            )
        return CreateTransactionResult(
            transaction=existing,
            http_status=CreateTransactionHttpStatus.CREATED,
        )

    def _apply_gateway_result(
        self,
        transaction_id: int,
        result: AuthorizeResult,
    ) -> Transaction:
        if result.outcome == GatewayOutcome.APPROVED:
            status = TransactionStatus.APPROVED
            message = message_for_code(result.response_code, approved=True)
        elif result.outcome == GatewayOutcome.DECLINED:
            status = TransactionStatus.DECLINED
            message = message_for_code(result.response_code, approved=False)
        elif result.outcome == GatewayOutcome.FAILED:
            status = TransactionStatus.FAILED
            message = MSG_FAILED
        else:
            status = TransactionStatus.UNKNOWN
            message = MSG_UNKNOWN

        return self._transactions.update_result(
            transaction_id=transaction_id,
            status=status,
            user_message=message,
            processor_response_code=result.response_code,
            auth_id=result.auth_id,
            retrieval_reference=result.retrieval_reference,
        )
