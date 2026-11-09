"""Auth HTTP request/response schemas."""

from typing import Annotated

from pydantic import BaseModel, Field
from pydantic.types import StringConstraints

InstallationId = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=8),
]


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=128)
    installation_id: InstallationId


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class MerchantResponse(BaseModel):
    code: str
    name: str
    address: str
    city: str
    tax_id: str


class AuthTokenResponse(BaseModel):
    name: str
    email: str
    token: str
    must_change_password: bool


class LoginTokenResponse(AuthTokenResponse):
    merchant: MerchantResponse


class CurrentMerchantResponse(BaseModel):
    merchant: MerchantResponse


class MessageResponse(BaseModel):
    message: str


class ErrorMessage(BaseModel):
    message: str
