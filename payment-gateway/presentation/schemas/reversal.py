"""HTTP schemas for technical reversals."""

from pydantic import BaseModel, Field, field_validator
from solidaridad_catalog import ProcessorCode

from domain.amount import AMOUNT_TOO_LARGE, MAX_AMOUNT_MINOR


class ReverseRequest(BaseModel):
    product_code: ProcessorCode
    amount_minor: int = Field(gt=0)
    card_number: str = Field(
        min_length=13,
        max_length=19,
        pattern=r"^\d+$",
        repr=False,
    )
    expiration_date: str = Field(min_length=4, max_length=4, pattern=r"^\d{4}$")
    terminal_id: str = Field(min_length=1, max_length=8)
    original_stan: str = Field(min_length=1, max_length=6, pattern=r"^\d+$")
    original_ticket: str = Field(min_length=1, max_length=24)
    reversal_stan: str = Field(min_length=1, max_length=6, pattern=r"^\d+$")

    @field_validator("amount_minor")
    @classmethod
    def amount_fits_de4(cls, value: int) -> int:
        if value > MAX_AMOUNT_MINOR:
            raise ValueError(AMOUNT_TOO_LARGE)
        return value


class ReversalResponse(BaseModel):
    status: str
    response_code: str
    user_message: str
