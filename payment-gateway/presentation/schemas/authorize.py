"""HTTP schemas for authorize."""

from pydantic import BaseModel, Field


class AuthorizeRequest(BaseModel):
    currency: str = Field(min_length=3, max_length=3)
    amount_minor: int = Field(gt=0)
    card_number: str = Field(min_length=13, max_length=19)
    terminal_id: str = Field(min_length=1, max_length=8)
    stan: str = Field(min_length=1, max_length=6)
    expiration_date: str | None = Field(default=None, max_length=4)


class AuthorizeResponse(BaseModel):
    status: str
    response_code: str
    user_message: str
    auth_id: str | None = None
    retrieval_reference: str | None = None
