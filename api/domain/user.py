"""User domain entity."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class UserRole(StrEnum):
    """Roles with access to API surfaces.

    Terminal users are deliberately the default.  A central operator must be
    provisioned through the administrative flow; it can never be selected by
    the public registration request.
    """

    TERMINAL = "TERMINAL"
    CENTRAL_OPERATOR = "CENTRAL_OPERATOR"


@dataclass(frozen=True, slots=True)
class User:
    id: int
    name: str
    email: str
    password_hash: str
    must_change_password: bool
    created_at: datetime
    updated_at: datetime
    role: UserRole = UserRole.TERMINAL
