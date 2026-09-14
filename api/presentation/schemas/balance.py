"""HTTP schemas for balance inquiry."""

from pydantic import BaseModel, Field


class BalanceInquiryRequest(BaseModel):
    card_number: str = Field(min_length=13, max_length=19)
    expiration_date: str | None = Field(default=None, max_length=4)
    entry_mode: str = Field(default="012", max_length=3)
    track2: str | None = Field(default=None, max_length=37)


class BalanceItemResponse(BaseModel):
    product: str
    label: str
    available_balance: str


class BalanceInquiryResponse(BaseModel):
    status: str
    user_message: str
    balances: list[BalanceItemResponse]
