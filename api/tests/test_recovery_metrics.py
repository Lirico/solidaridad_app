import logging
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient

from application.payments.embedded_recovery_worker import RecoveryWorkerHealth
from application.payments.ports import ReversalOutcome
from application.payments.recovery_alert_events import post_recovery_alert
from application.payments.recovery_metrics import summarize_recovery_metrics
from config import Settings
from domain.processor_job import ProcessorJobState
from main import create_app, load_recovery_metrics
from persistence.repositories.processor_job_repository import (
    ProcessorJobRepository,
    RecoveryStateAggregate,
)
from persistence.repositories.recovery_alert_repository import RecoveryAlertRepository
from presentation import create_router
from tests.test_reversal_job_worker import _build, _transaction

NOW = datetime(2026, 11, 12, 18, tzinfo=UTC)
PAN = "4242424242424242"


def _aggregate(
    state: ProcessorJobState,
    *,
    count: int,
    age: timedelta | None = None,
    attempts: int = 0,
    resolution_seconds: float | None = None,
) -> RecoveryStateAggregate:
    created_at = None if age is None else NOW - age
    return RecoveryStateAggregate(
        state=state.value,
        job_count=count,
        oldest_created_at=created_at,
        max_attempt_count=attempts,
        max_resolution_seconds=resolution_seconds,
    )


def test_summary_counts_every_state_and_ignores_closed_jobs_for_age() -> None:
    summary = summarize_recovery_metrics(
        [
            _aggregate(
                ProcessorJobState.READY,
                count=2,
                age=timedelta(seconds=30),
                attempts=1,
            ),
            _aggregate(
                ProcessorJobState.MANUAL_REVIEW,
                count=1,
                age=timedelta(minutes=5),
                attempts=4,
            ),
            _aggregate(
                ProcessorJobState.COMPLETED,
                count=3,
                age=timedelta(hours=2),
                attempts=9,
                resolution_seconds=125.9,
            ),
            _aggregate(
                ProcessorJobState.CANCELLED,
                count=1,
                resolution_seconds=10,
            ),
        ],
        open_alerts=2,
        now=NOW,
    )

    assert summary["jobs_by_state"] == {
        "READY": 2,
        "PROCESSING": 0,
        "RETRY": 0,
        "COMPLETED": 3,
        "CANCELLED": 1,
        "MANUAL_REVIEW": 1,
    }
    assert summary["oldest_unresolved_age_seconds"] == 300
    assert summary["max_attempt_count"] == 4
    assert summary["max_resolution_seconds"] == 125
    assert summary["open_alerts"] == 2
    assert PAN not in str(summary)


def test_summary_is_empty_when_the_queue_has_no_jobs() -> None:
    summary = summarize_recovery_metrics([], open_alerts=0, now=NOW)

    counts = summary["jobs_by_state"]
    assert isinstance(counts, dict)
    assert all(count == 0 for count in counts.values())
    assert summary["oldest_unresolved_age_seconds"] is None
    assert summary["max_attempt_count"] == 0
    assert summary["max_resolution_seconds"] is None


def test_repository_maps_grouped_job_rows() -> None:
    session = MagicMock()
    created = NOW - timedelta(seconds=12)
    session.execute.return_value.all.return_value = [
        ("RETRY", 2, created, 3, None),
    ]

    aggregates = ProcessorJobRepository(session).recovery_state_aggregates()

    assert aggregates == [
        RecoveryStateAggregate(
            state="RETRY",
            job_count=2,
            oldest_created_at=created,
            max_attempt_count=3,
            max_resolution_seconds=None,
        )
    ]


def test_open_alert_count_treats_an_empty_result_as_zero() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    assert RecoveryAlertRepository(session).count_open() == 0


def test_health_recovery_returns_the_snapshot() -> None:
    snapshot = summarize_recovery_metrics([], open_alerts=0, now=NOW)
    app = create_app(
        create_router(),
        settings=Settings(embedded_recovery_worker_enabled=False),
        recovery_worker=_idle_worker(),
        recovery_metrics=lambda: snapshot,
    )

    with TestClient(app) as client:
        response = client.get("/health/recovery")

    assert response.status_code == 200
    assert response.json()["open_alerts"] == 0
    assert "card_number" not in response.text


def test_health_recovery_is_unavailable_when_the_database_fails() -> None:
    def fail() -> dict[str, object]:
        raise RuntimeError("db down")

    app = create_app(
        create_router(),
        settings=Settings(embedded_recovery_worker_enabled=False),
        recovery_worker=_idle_worker(),
        recovery_metrics=fail,
    )

    with TestClient(app) as client:
        response = client.get("/health/recovery")

    assert response.status_code == 503
    assert response.json() == {
        "message": "No se pudieron leer las métricas de recuperación"
    }
    assert "db down" not in response.text


def test_default_reader_closes_the_session(monkeypatch: pytest.MonkeyPatch) -> None:
    session = MagicMock()
    session.execute.return_value.all.return_value = []
    session.scalar.return_value = 1
    monkeypatch.setattr(
        "persistence.database.SessionLocal",
        lambda: session,
    )

    summary = load_recovery_metrics()

    assert summary["open_alerts"] == 1
    session.close.assert_called_once_with()


def test_webhook_is_skipped_when_the_url_is_empty() -> None:
    with patch("application.payments.recovery_alert_events.httpx.post") as post:
        post_recovery_alert(
            url="  ",
            timeout_seconds=2,
            processor_job_id=7,
            transaction_number="OP-1",
            cause="INDETERMINATE",
        )

    post.assert_not_called()


def test_webhook_failure_is_logged_and_does_not_raise(
    caplog: pytest.LogCaptureFixture,
) -> None:
    with (
        caplog.at_level(logging.WARNING),
        patch(
            "application.payments.recovery_alert_events.httpx.post",
            side_effect=httpx.ConnectError("nope"),
        ),
    ):
        post_recovery_alert(
            url="https://ops.example/alerts",
            timeout_seconds=2,
            processor_job_id=7,
            transaction_number="OP-1",
            cause="INDETERMINATE",
        )

    assert any(
        record.message == "recovery_alert_webhook_failed" for record in caplog.records
    )


def test_worker_posts_a_new_alert_without_the_card_number() -> None:
    worker, _, _, _, alerts, _ = _build(
        transaction=_transaction(card_number=PAN, expiration_date="2912"),
        outcome=ReversalOutcome.INDETERMINATE,
        webhook_url="https://ops.example/alerts",
    )
    alerts.open_for_job.return_value = True

    with patch("application.payments.recovery_alert_events.httpx.post") as post:
        post.return_value.raise_for_status.return_value = None
        assert worker.run_once() is True

    body = post.call_args.kwargs["json"]
    assert body == {
        "processor_job_id": 7,
        "transaction_number": "OP-261014-00000011",
        "cause": "INDETERMINATE",
        "alert_state": "OPEN",
    }
    assert PAN not in str(body)
    assert "2912" not in str(body)
    post.assert_called_once()


def test_worker_does_not_post_a_duplicate_alert() -> None:
    worker, _, _, _, alerts, _ = _build(
        outcome=ReversalOutcome.INDETERMINATE,
        webhook_url="https://ops.example/alerts",
    )
    alerts.open_for_job.return_value = False

    with patch("application.payments.recovery_alert_events.httpx.post") as post:
        assert worker.run_once() is True

    post.assert_not_called()


def _idle_worker() -> MagicMock:
    worker = MagicMock()
    worker.health.return_value = RecoveryWorkerHealth(
        enabled=False,
        alive=False,
        stopping=False,
        started_at=None,
        last_iteration_at=None,
        last_error=None,
    )
    return worker
