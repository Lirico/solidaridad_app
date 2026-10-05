"""HTTP schemas for authorize / void."""

from pydantic import BaseModel, Field, field_validator
from solidaridad_catalog import ProcessorCode

from domain.amount import AMOUNT_TOO_LARGE, MAX_AMOUNT_MINOR


def _reject_amount_above_de4(value: int) -> int:
    if value > MAX_AMOUNT_MINOR:
        raise ValueError(AMOUNT_TOO_LARGE)
    return value


class AuthorizeRequest(BaseModel):
    product_code: ProcessorCode
    amount_minor: int = Field(gt=0)
    card_number: str = Field(min_length=13, max_length=19)
    terminal_id: str = Field(min_length=1, max_length=8)
    stan: str = Field(min_length=1, max_length=6)
    ticket_number: str = Field(min_length=1, max_length=24)
    expiration_date: str | None = Field(default=None, max_length=4)
    entry_mode: str = Field(default="012", max_length=3)
    track2: str | None = Field(default=None, max_length=37)

    @field_validator("amount_minor")
    @classmethod
    def amount_fits_de4(cls, value: int) -> int:
        return _reject_amount_above_de4(value)


class VoidRequest(BaseModel):
    product_code: ProcessorCode
    amount_minor: int = Field(gt=0)
    card_number: str = Field(min_length=13, max_length=19)
    terminal_id: str = Field(min_length=1, max_length=8)
    stan: str = Field(min_length=1, max_length=6)
    original_ticket: str = Field(min_length=1, max_length=24)
    void_ticket: str = Field(min_length=1, max_length=24)
    expiration_date: str | None = Field(default=None, max_length=4)

    @field_validator("amount_minor")
    @classmethod
    def amount_fits_de4(cls, value: int) -> int:
        return _reject_amount_above_de4(value)


class AuthorizeResponse(BaseModel):
    status: str
    response_code: str
    user_message: str
    auth_id: str | None = None
    retrieval_reference: str | None = None
