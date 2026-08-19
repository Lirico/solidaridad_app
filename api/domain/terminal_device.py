from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class TerminalDevice:
    id: int
    logical_device_id: str
    installation_id: str
    created_at: datetime
