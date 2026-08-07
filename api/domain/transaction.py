"""Payment transaction entity."""

from dataclasses import dataclass
from datetime import datetime

from domain.product import Product
from domain.transaction_status import TransactionStatus


@dataclass(frozen=True, slots=True)
class Transaction:
    id: int
    transaction_number: str
    user_id: int
    installation_id: int
    terminal_id: str
    product: Product
    processor_product_code: str
    amount_minor: int
    status: TransactionStatus
    card_last4: str
    stan: str | None
    auth_id: str | None
    retrieval_reference: str | None
    processor_response_code: str | None
    user_message: str | None
    idempotency_key: str
    request_fingerprint: str
    created_at: datetime
    updated_at: datetime
    processor_ticket: str | None = None
    void_idempotency_key: str | None = None
