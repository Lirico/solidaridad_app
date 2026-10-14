"""Project durable payment recovery state into the terminal contract."""

from dataclasses import dataclass
from enum import StrEnum

from application.payments.response_messages import MSG_UNDER_REVIEW
from domain.processor_job import ProcessorJob, ProcessorJobState
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus


class PendingReason(StrEnum):
    """The only recovery reasons exposed to a terminal."""

    PROCESSING = "PROCESSING"
    UNDER_REVIEW = "UNDER_REVIEW"


@dataclass(frozen=True, slots=True)
class PublicTransactionStatus:
    """Instructions a terminal needs without exposing processor job details."""

    status: str
    reason: PendingReason | None
    user_message: str
    poll_after_seconds: int | None
    may_start_new_sale: bool


POLL_AFTER_SECONDS = 2


def project_public_transaction_status(
    transaction: Transaction,
    reverse_job: ProcessorJob | None,
) -> PublicTransactionStatus:
    """Return the stable terminal-facing view of an authorization.

    A terminal never needs the worker state.  A pending authorization is
    either being recovered automatically, or it has reached a point where
    central-office review is required.  Final statuses deliberately omit all
    recovery metadata.
    """
    if transaction.status is TransactionStatus.PENDING:
        if reverse_job is not None and reverse_job.state is ProcessorJobState.MANUAL_REVIEW:
            return PublicTransactionStatus(
                status=TransactionStatus.PENDING.value,
                reason=PendingReason.UNDER_REVIEW,
                user_message=MSG_UNDER_REVIEW,
                poll_after_seconds=None,
                may_start_new_sale=True,
            )
        return PublicTransactionStatus(
            status=TransactionStatus.PENDING.value,
            reason=PendingReason.PROCESSING,
            user_message=transaction.user_message or "",
            poll_after_seconds=POLL_AFTER_SECONDS,
            may_start_new_sale=False,
        )

    return PublicTransactionStatus(
        status=transaction.status.value,
        reason=None,
        user_message=transaction.user_message or "",
        poll_after_seconds=None,
        may_start_new_sale=True,
    )
