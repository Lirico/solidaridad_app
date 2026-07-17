"""Authorization domain types."""

from dataclasses import dataclass
from enum import StrEnum


class AuthorizationStatus(StrEnum):
    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    FAILED = "FAILED"


@dataclass(frozen=True, slots=True)
class AuthorizeCommand:
    product_code: str
    amount_minor: int
    card_number: str
    terminal_id: str
    stan: str
    expiration_date: str | None = None


@dataclass(frozen=True, slots=True)
class AuthorizationResult:
    status: AuthorizationStatus
    response_code: str
    user_message: str
    auth_id: str | None = None
    retrieval_reference: str | None = None
