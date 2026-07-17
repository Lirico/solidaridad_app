"""HTTP schemas for transactions."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class CreateTransactionRequest(BaseModel):
    product: Literal[
        "GARRAFA_10",
        "GARRAFA_15",
        "GARRAFA_30",
        "TUBO_45",
        "GRANEL",
    ]
    amount: str = Field(min_length=1, max_length=32)
    card_number: str = Field(min_length=13, max_length=19)
    cvv: str = Field(min_length=3, max_length=4)
    expiration_date: str | None = Field(default=None, max_length=4)


class TransactionResponse(BaseModel):
    transaction_number: str
    status: str
    user_message: str
    created_at: datetime
