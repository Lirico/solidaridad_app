"""Ports for payment gateway integration."""

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Protocol


class GatewayOutcome(StrEnum):
    """Legacy outcome kept for balance and administrative void operations."""

    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    FAILED = "FAILED"
    UNKNOWN = "UNKNOWN"


class AuthorizationGatewayOutcome(StrEnum):
    """Exhaustive safety classification for one authorization attempt."""

    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    NOT_SENT = "NOT_SENT"
    INDETERMINATE = "INDETERMINATE"


class ReversalOutcome(StrEnum):
    REVERSED_CONFIRMED = "REVERSED_CONFIRMED"
    PROCESSOR_DECLINED = "PROCESSOR_DECLINED"
    NOT_SENT = "NOT_SENT"
    INDETERMINATE = "INDETERMINATE"


@dataclass(frozen=True, slots=True)
class AuthorizeRequest:
    product_code: str
    amount_minor: int
    card_number: str = field(repr=False)
    terminal_id: str
    stan: str
    ticket_number: str
    idempotency_key: str
    expiration_date: str | None = None


@dataclass(frozen=True, slots=True)
class VoidRequest:
    product_code: str
    amount_minor: int
    card_number: str = field(repr=False)
    terminal_id: str
    stan: str
    original_ticket: str
    void_ticket: str
    expiration_date: str | None = None


@dataclass(frozen=True, slots=True)
class AuthorizeResult:
    outcome: AuthorizationGatewayOutcome
    response_code: str | None = None
    user_message: str | None = None
    auth_id: str | None = None
    retrieval_reference: str | None = None


@dataclass(frozen=True, slots=True)
class BalanceRequest:
    product_code: str
    card_number: str = field(repr=False)
    terminal_id: str
    stan: str
    expiration_date: str | None = None


@dataclass(frozen=True, slots=True)
class BalanceResult:
    outcome: GatewayOutcome
    response_code: str | None = None
    user_message: str | None = None
    available_balance_minor: int | None = None
    assigned_products: str | None = None


@dataclass(frozen=True, slots=True)
class VoidResult:
    outcome: GatewayOutcome
    response_code: str | None = None
    user_message: str | None = None
    auth_id: str | None = None
    retrieval_reference: str | None = None


@dataclass(frozen=True, slots=True)
class ReverseRequest:
    product_code: str
    amount_minor: int
    card_number: str = field(repr=False)
    expiration_date: str
    terminal_id: str
    original_stan: str
    original_ticket: str
    reversal_stan: str


@dataclass(frozen=True, slots=True)
class ReverseResult:
    outcome: ReversalOutcome
    response_code: str | None = None
    user_message: str | None = None


class PaymentGateway(Protocol):
    def authorize(self, request: AuthorizeRequest) -> AuthorizeResult: ...

    def void(self, request: VoidRequest) -> VoidResult: ...

    def balance(self, request: BalanceRequest) -> BalanceResult: ...

    def reverse(self, request: ReverseRequest) -> ReverseResult: ...
