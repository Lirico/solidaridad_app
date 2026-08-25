"""Terminal device persistence repository."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.terminal_device import TerminalDevice
from persistence.models.terminal_device import TerminalDevice as TerminalDeviceModel


def _to_domain(row: TerminalDeviceModel) -> TerminalDevice:
    return TerminalDevice(
        id=row.id,
        logical_device_id=row.logical_device_id,
        installation_id=row.installation_id,
        created_at=row.created_at,
    )


class TerminalDeviceRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_logical_device_id(self, logical_device_id: str) -> TerminalDevice | None:
        row = self._session.scalar(
            select(TerminalDeviceModel).where(
                TerminalDeviceModel.logical_device_id == logical_device_id
            )
        )
        if row is None:
            return None
        return _to_domain(row)

    def get_by_installation_id(self, installation_id: str) -> TerminalDevice | None:
        row = self._session.scalar(
            select(TerminalDeviceModel).where(
                TerminalDeviceModel.installation_id == installation_id
            )
        )
        if row is None:
            return None
        return _to_domain(row)

    def create(
        self,
        *,
        logical_device_id: str,
        installation_id: str,
    ) -> TerminalDevice:
        row = TerminalDeviceModel(
            logical_device_id=logical_device_id,
            installation_id=installation_id,
        )
        self._session.add(row)
        self._session.flush()
        return _to_domain(row)
