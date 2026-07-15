"""User domain entity."""

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID


@dataclass(frozen=True, slots=True)
class User:
    id: UUID
    name: str
    email: str
    password_hash: str
    must_change_password: bool
    created_at: datetime
    updated_at: datetime
