"""Ports for payment gateway integration."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol


class GatewayOutcome(StrEnum):
    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    FAILED = "FAILED"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True, slots=True)
class AuthorizeRequest:
    product_code: str
    amount_minor: int
    card_number: str
    terminal_id: str
    stan: str
    expiration_date: str | None = None


@dataclass(frozen=True, slots=True)
class AuthorizeResult:
    outcome: GatewayOutcome
    response_code: str | None = None
    user_message: str | None = None
    auth_id: str | None = None
    retrieval_reference: str | None = None


class PaymentGateway(Protocol):
    def authorize(self, request: AuthorizeRequest) -> AuthorizeResult: ...
