"""HTTP schemas for transactions."""

from datetime import datetime

from pydantic import BaseModel, Field
from solidaridad_catalog import Product


class CreateTransactionRequest(BaseModel):
    product: Product
    amount: str = Field(min_length=1, max_length=32)
    card_number: str = Field(min_length=13, max_length=19)
    # CVV opcional: la banda magnética (entry_mode 022) no lo contiene.
    # La validación de CVV se hace en el caso de uso según el entry_mode.
    cvv: str | None = Field(default=None, max_length=4)
    expiration_date: str | None = Field(default=None, max_length=4)
    entry_mode: str = Field(default="012", max_length=3)
    track2: str | None = Field(default=None, max_length=37)



class VoidTransactionRequest(BaseModel):
    card_number: str = Field(min_length=13, max_length=19)
    cvv: str | None = Field(default=None, min_length=3, max_length=4)
    expiration_date: str | None = Field(default=None, max_length=4)


class TransactionResponse(BaseModel):
    transaction_number: str
    status: str
    user_message: str
    created_at: datetime


class TransactionItemResponse(BaseModel):
    """Single item in a transaction list response."""

    transaction_number: str
    product: str
    amount: str
    card_last4: str
    status: str
    user_message: str
    created_at: datetime


class TransactionListResponse(BaseModel):
    """Paginated list of transactions."""

    items: list[TransactionItemResponse]
    total: int