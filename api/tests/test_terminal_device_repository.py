from datetime import UTC, datetime
from unittest.mock import MagicMock

from persistence.models.terminal_device import TerminalDevice as TerminalDeviceModel
from persistence.repositories.terminal_device_repository import (
    TerminalDeviceRepository,
)


def _terminal_row() -> MagicMock:
    now = datetime.now(UTC)
    row = MagicMock(spec=TerminalDeviceModel)
    row.id = 7
    row.logical_device_id = "V660P-DEMO-0001"
    row.installation_id = "05000001"
    row.created_at = now
    return row


def test_get_by_logical_device_id_returns_match() -> None:
    session = MagicMock()
    session.scalar.return_value = _terminal_row()

    device = TerminalDeviceRepository(session).get_by_logical_device_id(
        "V660P-DEMO-0001"
    )

    assert device is not None
    assert device.id == 7
    assert device.logical_device_id == "V660P-DEMO-0001"
    assert device.installation_id == "05000001"


def test_get_by_logical_device_id_returns_none_when_missing() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    assert TerminalDeviceRepository(session).get_by_logical_device_id("UNKNOWN") is None


def test_get_by_installation_id_returns_match() -> None:
    session = MagicMock()
    session.scalar.return_value = _terminal_row()

    device = TerminalDeviceRepository(session).get_by_installation_id("05000001")

    assert device is not None
    assert device.installation_id == "05000001"


def test_get_by_installation_id_returns_none_when_missing() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    assert TerminalDeviceRepository(session).get_by_installation_id("99999999") is None


def test_create_adds_and_flushes_row() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    device = TerminalDeviceRepository(session).create(
        logical_device_id="V660P-DEMO-0001",
        installation_id="05000001",
    )

    row = session.add.call_args.args[0]
    assert row.logical_device_id == "V660P-DEMO-0001"
    assert row.installation_id == "05000001"
    assert device.logical_device_id == "V660P-DEMO-0001"
    assert device.installation_id == "05000001"
    session.flush.assert_called_once()
