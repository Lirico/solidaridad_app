"""Auth HTTP request/response schemas."""

from typing import Annotated

from pydantic import BaseModel, EmailStr, Field
from pydantic.types import StringConstraints

InstallationId = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=8),
]


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    installation_id: InstallationId


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=128)
    installation_id: InstallationId


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class AuthTokenResponse(BaseModel):
    name: str
    email: str
    token: str
    must_change_password: bool


class MessageResponse(BaseModel):
    message: str


class ErrorMessage(BaseModel):
    message: str
