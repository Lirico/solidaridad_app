"""Balance inquiry (0100) domain types."""

from dataclasses import dataclass

from domain.authorization import AuthorizationStatus


@dataclass(frozen=True, slots=True)
class BalanceCommand:
    product_code: str
    card_number: str
    terminal_id: str
    stan: str
    expiration_date: str | None = None
    entry_mode: str = "012"
    track2: str | None = None


@dataclass(frozen=True, slots=True)
class BalanceResult:
    status: AuthorizationStatus
    response_code: str
    user_message: str
    available_balance_minor: int | None = None
    assigned_products: str | None = None
