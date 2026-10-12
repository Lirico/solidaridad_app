"""Technical reversal domain types."""

from dataclasses import dataclass
from enum import StrEnum


class ReversalStatus(StrEnum):
    """Safe outcome of one reversal attempt."""

    REVERSED_CONFIRMED = "REVERSED_CONFIRMED"
    ORIGINAL_NOT_FOUND = "ORIGINAL_NOT_FOUND"
    PROCESSOR_DECLINED = "PROCESSOR_DECLINED"
    NOT_SENT = "NOT_SENT"
    INDETERMINATE = "INDETERMINATE"


@dataclass(frozen=True, slots=True)
class ReverseCommand:
    product_code: str
    amount_minor: int
    card_number: str
    expiration_date: str
    terminal_id: str
    original_stan: str
    original_ticket: str
    reversal_stan: str


@dataclass(frozen=True, slots=True)
class ReversalResult:
    status: ReversalStatus
    response_code: str
    user_message: str
