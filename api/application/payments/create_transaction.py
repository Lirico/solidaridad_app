"""Create and authorize a payment transaction."""

import hashlib
import random
import secrets
import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from enum import IntEnum

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from application.payments.authorization_retry import AuthorizationRetryPolicy
from application.payments.ports import (
    AuthorizationGatewayOutcome,
    AuthorizeRequest,
    AuthorizeResult,
    PaymentGateway,
)
from application.payments.public_transaction_status import (
    PublicTransactionStatus,
    project_public_transaction_status,
)
from application.payments.response_messages import (
    MSG_FAILED,
    MSG_PENDING,
    MSG_UNKNOWN,
    message_for_code,
)
from domain.authorization_outcome import AuthorizationOutcome
from domain.exceptions import (
    IdempotencyConflict,
    InvalidAmount,
    InvalidCardNumber,
    InvalidCvv,
    MissingIdempotencyKey,
    MissingTerminalId,
)
from domain.money import Money, parse_amount
from domain.processor_job import ProcessorOperationType
from domain.product import (
    Product,
    parse_product,
    processor_product_code,
    requires_integer_quantity,
)
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from persistence.repositories.installation_repository import InstallationRepository
from persistence.repositories.payment_processing_config_repository import (
    PaymentProcessingConfigRepository,
)
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.transaction_repository import (
    TransactionRepository,
    ticket_from_transaction_number,
)


class CreateTransactionHttpStatus(IntEnum):
    CREATED = 201
    OK = 200
    ACCEPTED = 202


@dataclass(frozen=True, slots=True)
class CreateTransactionResult:
    transaction: Transaction
    http_status: CreateTransactionHttpStatus
    public_status: PublicTransactionStatus | None = None


def _fingerprint(
    *,
    product: Product,
    amount_minor: int,
    card_number: str,
    expiration_date: str | None,
) -> str:
    raw = "|".join(
        [
            product.value,
            str(amount_minor),
            card_number,
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
        configs: PaymentProcessingConfigRepository,
        jobs: ProcessorJobRepository,
        sleep: Callable[[float], None] = time.sleep,
        monotonic: Callable[[], float] = time.monotonic,
        random_value: Callable[[], float] = random.random,
    ) -> None:
        self._session = session
        self._transactions = transactions
        self._installations = installations
        self._gateway = gateway
        self._configs = configs
        self._jobs = jobs
        self._sleep = sleep
        self._monotonic = monotonic
        self._random_value = random_value

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
    ) -> CreateTransactionResult:

        if idempotency_key is None or not idempotency_key.strip():
            raise MissingIdempotencyKey()
        key = idempotency_key.strip()

        parsed_product = parse_product(product)
        money: Money = parse_amount(amount)
        if (
            requires_integer_quantity(parsed_product)
            and money.amount_minor % 100 != 0
        ):
            raise InvalidAmount("La cantidad debe ser un número entero")
        pan = _validate_pan(card_number)
        exp = expiration_date.strip() if expiration_date else None
        if exp == "":
            exp = None
        # El gateway/procesador no usan CVV en este flujo. Si un cliente legado
        # lo manda, solo se valida su formato y nunca se persiste ni reenvía.
        if cvv and cvv.strip():
            _validate_cvv(cvv)
        fingerprint = _fingerprint(
            product=parsed_product,
            amount_minor=money.amount_minor,
            card_number=pan,
            expiration_date=exp,
        )

        existing = self._transactions.get_by_idempotency(
            user_id=user_id,
            idempotency_key=key,
        )
        if existing is not None:
            return self._replay(existing, fingerprint, idempotency_key=key)

        policy = AuthorizationRetryPolicy.from_config(
            self._configs.get_default(),
            random_value=self._random_value,
        )

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
                card_last4=pan[-4:],
                card_number=pan,
                expiration_date=exp,
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

        authorization_request = AuthorizeRequest(
            product_code=proc_code,
            amount_minor=money.amount_minor,
            card_number=pan,
            terminal_id=terminal_id[:8].ljust(8),
            stan=stan,
            ticket_number=processor_ticket,
            idempotency_key=key,
            expiration_date=exp,
        )
        gateway_result = self._authorize_with_safe_retries(
            transaction_id=pending.id,
            request=authorization_request,
            policy=policy,
        )
        try:
            final = self._apply_gateway_result(pending, gateway_result)
            # For an ambiguous authorization this is one database transaction:
            # the public PENDING state, the recovery job and both audit events.
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
        return self._result(final, created=True)

    def _authorize_with_safe_retries(
        self,
        *,
        transaction_id: int,
        request: AuthorizeRequest,
        policy: AuthorizationRetryPolicy,
    ) -> AuthorizeResult:
        deadline = self._monotonic() + policy.processing_timeout_seconds
        attempt_number = 1

        while True:
            result = self._gateway.authorize(request)
            self._transactions.record_authorization_attempt(
                transaction_id=transaction_id,
                attempt_number=attempt_number,
                outcome=AuthorizationOutcome(result.outcome.value),
                processor_response_code=result.response_code,
            )
            self._session.commit()

            if (
                result.outcome != AuthorizationGatewayOutcome.NOT_SENT
                or attempt_number >= policy.max_attempts
            ):
                return result

            next_attempt = attempt_number + 1
            delay = policy.delay_before_attempt(next_attempt)
            if self._monotonic() + delay > deadline:
                return result
            self._sleep(delay)
            attempt_number = self._transactions.start_authorization_retry(
                transaction_id=transaction_id
            )
            self._session.commit()

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
        return self._result(existing)

    def _result(
        self, transaction: Transaction, *, created: bool = False
    ) -> CreateTransactionResult:
        reverse_job = self._jobs.get_by_transaction(
            transaction_id=transaction.id,
            operation_type=ProcessorOperationType.REVERSE,
        )
        return CreateTransactionResult(
            transaction=transaction,
            http_status=(
                CreateTransactionHttpStatus.ACCEPTED
                if transaction.status == TransactionStatus.PENDING
                else (
                    CreateTransactionHttpStatus.CREATED
                    if created
                    else CreateTransactionHttpStatus.OK
                )
            ),
            public_status=project_public_transaction_status(transaction, reverse_job),
        )

    def _apply_gateway_result(
        self,
        transaction: Transaction,
        result: AuthorizeResult,
    ) -> Transaction:
        if result.outcome == AuthorizationGatewayOutcome.APPROVED:
            status = TransactionStatus.APPROVED
            authorization_outcome = AuthorizationOutcome.APPROVED
            message = message_for_code(result.response_code, approved=True)
        elif result.outcome == AuthorizationGatewayOutcome.DECLINED:
            status = TransactionStatus.DECLINED
            authorization_outcome = AuthorizationOutcome.DECLINED
            message = message_for_code(result.response_code, approved=False)
        elif result.outcome == AuthorizationGatewayOutcome.NOT_SENT:
            status = TransactionStatus.FAILED
            authorization_outcome = AuthorizationOutcome.NOT_SENT
            message = MSG_FAILED
        else:
            status = TransactionStatus.PENDING
            authorization_outcome = AuthorizationOutcome.INDETERMINATE
            message = MSG_UNKNOWN

        if result.outcome == AuthorizationGatewayOutcome.INDETERMINATE:
            # Serializes this path with the stale-PENDING watchdog.  Once the
            # lock is held, a replay/recovery race can observe an existing job
            # instead of creating a second one.
            transaction = self._transactions.get_by_id_for_update(
                transaction_id=transaction.id
            )

        updated = self._transactions.update_result(
            transaction_id=transaction.id,
            status=status,
            authorization_outcome=authorization_outcome,
            user_message=message,
            processor_response_code=result.response_code,
            auth_id=result.auth_id,
            retrieval_reference=result.retrieval_reference,
        )
        if result.outcome != AuthorizationGatewayOutcome.INDETERMINATE:
            return updated

        existing_job = self._jobs.get_by_transaction(
            transaction_id=transaction.id,
            operation_type=ProcessorOperationType.REVERSE,
        )
        if existing_job is None:
            if transaction.stan is None or transaction.processor_ticket is None:
                raise ValueError(
                    "ambiguous authorization is missing recovery identifiers"
                )
            self._jobs.create_reverse(
                transaction_id=transaction.id,
                original_stan=transaction.stan,
                original_ticket=transaction.processor_ticket,
                reversal_stan=f"{secrets.randbelow(1_000_000):06d}",
                next_attempt_at=datetime.now(UTC),
            )
            self._transactions.record_reversal_enqueued(transaction_id=transaction.id)
        return updated
