from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.payments.embedded_recovery_worker import RecoveryWorkerHealth
from config import Settings
from domain.processor_job import ProcessorJobState
from infrastructure.payments.recovery_metrics import (
    RecoveryJobMetric,
    RecoveryMetricsExporter,
    RecoveryResolutionMetric,
)
from main import create_app
from presentation import create_router

NOW = datetime(2026, 10, 14, 12, tzinfo=UTC)


def test_metrics_render_job_state_age_attempts_and_resolution_time() -> None:
    exporter = RecoveryMetricsExporter(now=lambda: NOW)

    metrics = exporter._render(
        [
            RecoveryJobMetric(
                state=ProcessorJobState.RETRY,
                count=2,
                oldest_created_at=NOW - timedelta(seconds=90),
                max_attempt_count=3,
            )
        ],
        RecoveryResolutionMetric(count=4, seconds_total=120.5),
    )

    assert 'solidaridad_recovery_jobs{state="RETRY"} 2' in metrics
    assert 'solidaridad_recovery_oldest_job_age_seconds{state="RETRY"} 90.0' in metrics
    assert 'solidaridad_recovery_max_attempts{state="RETRY"} 3' in metrics
    assert "solidaridad_recovery_resolution_seconds_total 120.5" in metrics
    assert "solidaridad_recovery_resolutions_total 4" in metrics
    assert 'solidaridad_recovery_jobs{state="MANUAL_REVIEW"} 0' in metrics


def test_metrics_endpoint_exposes_only_the_metrics_snapshot() -> None:
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
        settings=Settings(),
        recovery_worker=worker,
        recovery_metrics=lambda: "solidaridad_recovery_jobs{state=\"READY\"} 1\n",
    )

    with TestClient(app) as client:
        response = client.get("/metrics")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/plain; version=0.0.4")
    assert response.text == 'solidaridad_recovery_jobs{state="READY"} 1\n'
