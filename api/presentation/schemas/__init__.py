"""Auth presentation schemas package."""

from presentation.schemas.auth import (
    AuthTokenResponse,
    ChangePasswordRequest,
    ErrorMessage,
    LoginRequest,
    MessageResponse,
    RegisterRequest,
)
from presentation.schemas.terminals import (
    ResolveTerminalRequest,
    ResolveTerminalResponse,
)

__all__ = [
    "AuthTokenResponse",
    "ChangePasswordRequest",
    "ErrorMessage",
    "LoginRequest",
    "MessageResponse",
    "RegisterRequest",
    "ResolveTerminalRequest",
    "ResolveTerminalResponse",
]
