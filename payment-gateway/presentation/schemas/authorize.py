"""HTTP schemas for authorize / void."""

from pydantic import BaseModel, Field
from solidaridad_catalog import ProcessorCode


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
    # CVV opcional (modo manual 012). La banda (022) no lo trae.
    cvv: str | None = Field(default=None, max_length=4)


class VoidRequest(BaseModel):
    product_code: ProcessorCode
    amount_minor: int = Field(gt=0)
    card_number: str = Field(min_length=13, max_length=19)
    terminal_id: str = Field(min_length=1, max_length=8)
    stan: str = Field(min_length=1, max_length=6)
    original_ticket: str = Field(min_length=1, max_length=24)
    void_ticket: str = Field(min_length=1, max_length=24)
    expiration_date: str | None = Field(default=None, max_length=4)


class AuthorizeResponse(BaseModel):
    status: str
    response_code: str
    user_message: str
    auth_id: str | None = None
    retrieval_reference: str | None = None
