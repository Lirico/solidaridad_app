from datetime import UTC, datetime, timedelta
from decimal import Decimal
from unittest.mock import MagicMock

from application.payments.stale_processing_job_monitor import (
    StaleProcessingJobMonitor,
)
from domain.payment_processing_config import PaymentProcessingConfig

NOW = datetime(2026, 10, 14, 12, tzinfo=UTC)


def _config() -> PaymentProcessingConfig:
    return PaymentProcessingConfig(
        id=1,
        config_name="default",
        max_authorization_attempts=3,
        authorization_initial_delay_ms=100,
        authorization_max_delay_ms=500,
        authorization_backoff_multiplier=Decimal("2"),
        max_reversal_attempts=2,
        reversal_initial_delay_seconds=5,
        reversal_max_delay_seconds=30,
        reversal_backoff_multiplier=Decimal("2"),
        jitter_percentage=0,
        processing_timeout_seconds=60,
        worker_poll_interval_seconds=Decimal("1"),
        created_at=NOW,
        updated_at=NOW,
    )


def test_monitor_moves_a_job_at_the_exact_timeout_boundary() -> None:
    session = MagicMock()
    jobs = MagicMock()
    alerts = MagicMock()
    configs = MagicMock()
    configs.get_default.return_value = _config()
    jobs.move_next_stale_processing_to_manual_review.return_value = MagicMock()
    monitor = StaleProcessingJobMonitor(
        session=session,
        jobs=jobs,
        alerts=alerts,
        configs=configs,
        now=lambda: NOW,
    )

    assert monitor.run_once() is True

    jobs.move_next_stale_processing_to_manual_review.assert_called_once_with(
        processing_started_before=NOW - timedelta(seconds=60),
        reviewed_at=NOW,
    )
    session.commit.assert_called_once()
    alerts.open_for_job.assert_called_once_with(
        processor_job_id=jobs.move_next_stale_processing_to_manual_review.return_value.id,
        cause="PROCESSING_TIMEOUT",
        opened_at=NOW,
    )


def test_monitor_commits_no_change_when_no_job_is_stale() -> None:
    session = MagicMock()
    jobs = MagicMock()
    alerts = MagicMock()
    configs = MagicMock()
    configs.get_default.return_value = _config()
    jobs.move_next_stale_processing_to_manual_review.return_value = None
    monitor = StaleProcessingJobMonitor(
        session=session,
        jobs=jobs,
        alerts=alerts,
        configs=configs,
        now=lambda: NOW,
    )

    assert monitor.run_once() is False

    session.commit.assert_called_once()
    alerts.open_for_job.assert_not_called()


def test_monitor_rolls_back_when_persistence_fails() -> None:
    session = MagicMock()
    jobs = MagicMock()
    alerts = MagicMock()
    configs = MagicMock()
    configs.get_default.side_effect = RuntimeError("missing configuration")
    monitor = StaleProcessingJobMonitor(
        session=session,
        jobs=jobs,
        alerts=alerts,
        configs=configs,
        now=lambda: NOW,
    )

    try:
        monitor.run_once()
    except RuntimeError:
        pass
    else:
        raise AssertionError("expected configuration error")

    session.rollback.assert_called_once()
