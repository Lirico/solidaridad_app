from datetime import UTC, datetime
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.payments.embedded_recovery_worker import RecoveryWorkerHealth
from config import Settings
from main import create_app
from presentation import create_router

NOW = datetime(2026, 10, 14, 12, tzinfo=UTC)


def _health(*, alive: bool, last_error: str | None = None) -> RecoveryWorkerHealth:
    return RecoveryWorkerHealth(
        enabled=True,
        alive=alive,
        stopping=False,
        started_at=NOW,
        last_iteration_at=NOW if alive else None,
        last_error=last_error,
    )


def test_lifespan_starts_and_stops_one_embedded_worker() -> None:
    worker = MagicMock()
    worker.health.return_value = _health(alive=True)
    app = create_app(
        create_router(),
        settings=Settings(embedded_recovery_worker_enabled=True),
        recovery_worker=worker,
    )

    with TestClient(app) as client:
        assert client.get("/health/live").json() == {"status": "ok"}
        response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json()["recovery_worker"]["alive"] is True
    worker.start.assert_called_once_with()
    worker.stop.assert_called_once_with(grace_seconds=40.0)


def test_readiness_is_degraded_after_a_fatal_worker_error() -> None:
    worker = MagicMock()
    worker.health.return_value = _health(alive=False, last_error="RuntimeError")
    app = create_app(
        create_router(),
        settings=Settings(embedded_recovery_worker_enabled=True),
        recovery_worker=worker,
    )

    with TestClient(app) as client:
        response = client.get("/health/ready")

    assert response.status_code == 503
    assert response.json() == {
        "status": "degraded",
        "recovery_worker": {
            "enabled": True,
            "alive": False,
            "stopping": False,
            "started_at": "2026-10-14T12:00:00+00:00",
            "last_iteration_at": None,
            "last_error": "RuntimeError",
        },
    }


def test_disabled_worker_is_ready_before_operational_activation() -> None:
    worker = MagicMock()
    worker.health.return_value = RecoveryWorkerHealth(
        enabled=False,
        alive=False,
        stopping=False,
        started_at=None,
        last_iteration_at=None,
        last_error=None,
    )
    app = create_app(
        create_router(),
        settings=Settings(embedded_recovery_worker_enabled=False),
        recovery_worker=worker,
    )

    with TestClient(app) as client:
        response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json()["recovery_worker"]["enabled"] is False
    worker.start.assert_not_called()
    worker.stop.assert_not_called()
