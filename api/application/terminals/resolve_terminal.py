"""Resolve a hardware logical_device_id to its processor terminal id."""

from dataclasses import dataclass

from domain.exceptions import TerminalNotProvisioned
from persistence.repositories.terminal_device_repository import (
    TerminalDeviceRepository,
)


@dataclass(frozen=True, slots=True)
class ResolveTerminalResult:
    installation_id: str


class ResolveTerminal:
    def __init__(self, devices: TerminalDeviceRepository) -> None:
        self._devices = devices

    def execute(self, *, logical_device_id: str) -> ResolveTerminalResult:
        normalized = logical_device_id.strip()
        device = self._devices.get_by_logical_device_id(normalized)
        if device is None:
            raise TerminalNotProvisioned()
        return ResolveTerminalResult(installation_id=device.installation_id)
