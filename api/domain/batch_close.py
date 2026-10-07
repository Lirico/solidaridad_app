"""Administrative terminal batch close entities."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class BatchClose:
    """An immutable administrative cut for one terminal."""

    id: int
    installation_id: int
    terminal_id: str
    closed_by_user_id: int
    idempotency_key: str
    closed_at: datetime
