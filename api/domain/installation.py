"""Installation domain entity."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class Installation:
    id: str
    platform: str | None
    last_seen_at: datetime
    created_at: datetime
