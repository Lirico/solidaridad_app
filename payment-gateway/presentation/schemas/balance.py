"""HTTP schemas for balance inquiry."""

from pydantic import BaseModel, Field
from solidaridad_catalog import ProcessorCode


class BalanceRequest(BaseModel):
    product_code: ProcessorCode
    card_number: str = Field(min_length=13, max_length=19)
    terminal_id: str = Field(min_length=1, max_length=8)
    stan: str = Field(min_length=1, max_length=6)
    expiration_date: str | None = Field(default=None, max_length=4)
    entry_mode: str = Field(default="012", max_length=3)
    track2: str | None = Field(default=None, max_length=37)


class BalanceResponse(BaseModel):
    status: str
    response_code: str
    user_message: str
    available_balance_minor: int | None = None
    assigned_products: str | None = None
