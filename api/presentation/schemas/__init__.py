"""Auth presentation schemas package."""

from presentation.schemas.auth import (
    AuthTokenResponse,
    ErrorMessage,
    LoginRequest,
    RegisterRequest,
)

__all__ = [
    "AuthTokenResponse",
    "ErrorMessage",
    "LoginRequest",
    "RegisterRequest",
]
