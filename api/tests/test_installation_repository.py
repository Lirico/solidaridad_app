from datetime import UTC, datetime
from unittest.mock import MagicMock

from persistence.models.installation import Installation as InstallationModel
from persistence.repositories.installation_repository import InstallationRepository


def _installation_row() -> MagicMock:
    now = datetime.now(UTC)
    row = MagicMock(spec=InstallationModel)
    row.id = 10
    row.installation_id = "05000001"
    row.platform = None
    row.last_seen_at = now
    row.created_at = now
    return row


def test_get_by_installation_id_returns_business_key_match() -> None:
    session = MagicMock()
    session.scalar.return_value = _installation_row()

    installation = InstallationRepository(session).get_by_installation_id(
        "05000001"
    )

    assert installation is not None
    assert installation.id == 10
    assert installation.installation_id == "05000001"


def test_get_by_installation_id_returns_none_when_missing() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    assert (
        InstallationRepository(session).get_by_installation_id("99999999") is None
    )


def test_upsert_creates_installation_with_functional_key() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    installation = InstallationRepository(session).upsert(
        "05000001",
        platform="android",
    )

    row = session.add.call_args.args[0]
    assert row.installation_id == "05000001"
    assert row.platform == "android"
    assert installation.installation_id == "05000001"
    session.flush.assert_called_once()


def test_upsert_updates_existing_installation() -> None:
    session = MagicMock()
    row = _installation_row()
    session.scalar.return_value = row

    installation = InstallationRepository(session).upsert(
        "05000001",
        platform="android",
    )

    assert row.platform == "android"
    assert installation.id == 10
    session.add.assert_not_called()
    session.flush.assert_called_once()
