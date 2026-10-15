"""Durable recovery alert entities."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class RecoveryAlertState(StrEnum):
    OPEN = "OPEN"


@dataclass(frozen=True, slots=True)
class RecoveryAlert:
    id: int
    processor_job_id: int
    cause: str
    state: RecoveryAlertState
    opened_at: datetime
    created_at: datetime
