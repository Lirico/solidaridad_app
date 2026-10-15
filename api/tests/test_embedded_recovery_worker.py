from datetime import UTC, datetime
from threading import Event

import pytest

from application.payments.embedded_recovery_worker import EmbeddedRecoveryWorker

NOW = datetime(2026, 10, 14, 12, tzinfo=UTC)


def test_worker_runs_in_a_dedicated_thread_and_stops_while_idle() -> None:
    completed = Event()
    calls = 0

    def run_iteration(_should_stop: object) -> float:
        nonlocal calls
        calls += 1
        completed.set()
        return 60

    worker = EmbeddedRecoveryWorker(run_iteration=run_iteration, now=lambda: NOW)
    worker.start()

    assert completed.wait(timeout=1)
    assert worker.health().ready is True
    assert worker.stop(grace_seconds=1) is True
    assert calls == 1
    assert worker.health().alive is False


def test_worker_waits_for_an_in_progress_iteration_during_shutdown() -> None:
    started = Event()
    release = Event()

    def run_iteration(_should_stop: object) -> float:
        started.set()
        release.wait(timeout=1)
        return 60

    worker = EmbeddedRecoveryWorker(run_iteration=run_iteration)
    worker.start()
    assert started.wait(timeout=1)

    assert worker.stop(grace_seconds=0) is False
    assert worker.health().stopping is True
    release.set()
    assert worker.stop(grace_seconds=1) is True


def test_fatal_iteration_error_degrades_readiness() -> None:
    worker = EmbeddedRecoveryWorker(
        run_iteration=lambda _should_stop: (_ for _ in ()).throw(
            RuntimeError("database down")
        )
    )
    worker.start()

    assert worker.stop(grace_seconds=1) is True
    health = worker.health()
    assert health.ready is False
    assert health.last_error == "RuntimeError"


def test_disabled_worker_is_ready_without_starting_a_thread() -> None:
    worker = EmbeddedRecoveryWorker(
        run_iteration=lambda _should_stop: 1,
        enabled=False,
    )

    worker.start()

    assert worker.health().ready is True
    assert worker.health().alive is False


def test_worker_can_only_be_started_once() -> None:
    worker = EmbeddedRecoveryWorker(run_iteration=lambda _should_stop: 60)
    worker.start()

    with pytest.raises(RuntimeError, match="already started"):
        worker.start()

    assert worker.stop(grace_seconds=1) is True


def test_shutdown_grace_must_not_be_negative() -> None:
    worker = EmbeddedRecoveryWorker(run_iteration=lambda _should_stop: 60)

    with pytest.raises(ValueError, match="grace_seconds"):
        worker.stop(grace_seconds=-1)


def test_worker_requires_a_positive_iteration_age_threshold() -> None:
    with pytest.raises(ValueError, match="max_iteration_age_seconds"):
        EmbeddedRecoveryWorker(
            run_iteration=lambda _should_stop: 60,
            max_iteration_age_seconds=0,
        )
