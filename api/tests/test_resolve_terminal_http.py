from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.terminals.resolve_terminal import ResolveTerminal
from main import app
from persistence.repositories.terminal_device_repository import (
    TerminalDeviceRepository,
)
from presentation.dependencies import get_resolve_terminal

client = TestClient(app)


def _override(repo: TerminalDeviceRepository) -> None:
    app.dependency_overrides[get_resolve_terminal] = lambda: ResolveTerminal(repo)


def _clear() -> None:
    app.dependency_overrides.clear()


def test_resolve_terminal_returns_installation_id() -> None:
    repo = MagicMock(spec=TerminalDeviceRepository)
    repo.get_by_logical_device_id.return_value = MagicMock(installation_id="05000001")
    _override(repo)
    try:
        response = client.post(
            "/v1/terminals/resolve",
            json={"logical_device_id": "V660P-DEMO-0001"},
        )
        assert response.status_code == 200
        assert response.json() == {"installation_id": "05000001"}
    finally:
        _clear()


def test_resolve_terminal_returns_404_when_not_provisioned() -> None:
    repo = MagicMock(spec=TerminalDeviceRepository)
    repo.get_by_logical_device_id.return_value = None
    _override(repo)
    try:
        response = client.post(
            "/v1/terminals/resolve",
            json={"logical_device_id": "UNKNOWN-DEVICE"},
        )
        assert response.status_code == 404
        assert response.json() == {"message": "La terminal no está provisionada"}
    finally:
        _clear()


def test_resolve_terminal_rejects_invalid_logical_device_id() -> None:
    _clear()
    response = client.post(
        "/v1/terminals/resolve",
        json={"logical_device_id": "invalid id with spaces!"},
    )
    assert response.status_code == 400


