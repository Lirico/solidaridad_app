"""User domain entity."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class User:
    id: int
    name: str
    email: str
    password_hash: str
    must_change_password: bool
    created_at: datetime
    updated_at: datetime
