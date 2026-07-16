"""Auth HTTP request/response schemas."""

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    installation_id: str = Field(min_length=1, max_length=128)


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=128)
    installation_id: str = Field(min_length=1, max_length=128)


class AuthTokenResponse(BaseModel):
    name: str
    email: str
    token: str
    must_change_password: bool


class ErrorMessage(BaseModel):
    message: str
