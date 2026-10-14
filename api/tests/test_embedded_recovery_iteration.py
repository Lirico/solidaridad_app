from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from application.payments import embedded_recovery_iteration
from config import Settings


class _ConfigRepository:
    def __init__(self, _session: object) -> None:
        pass

    def get_default(self) -> SimpleNamespace:
        return SimpleNamespace(worker_poll_interval_seconds=Decimal("2.5"))


def test_iteration_uses_a_fresh_session_and_runs_recovery_and_monitor(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    session = MagicMock()
    gateway = MagicMock()
    reversal = MagicMock()
    monitor = MagicMock()
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "PaymentProcessingConfigRepository",
        _ConfigRepository,
    )
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "ReversalJobWorker",
        lambda **_kwargs: reversal,
    )
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "StaleProcessingJobMonitor",
        lambda **_kwargs: monitor,
    )
    iteration = embedded_recovery_iteration.create_embedded_recovery_iteration(
        settings=Settings(),
        worker_id="test-worker",
        session_factory=lambda: session,
        gateway_factory=lambda: gateway,
    )

    assert iteration(lambda: False) == 2.5

    reversal.run_once.assert_called_once_with()
    monitor.run_once.assert_called_once_with()
    session.rollback.assert_called_once_with()
    session.close.assert_called_once_with()
    gateway.close.assert_called_once_with()


def test_iteration_does_not_claim_work_after_shutdown_was_requested(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    session = MagicMock()
    gateway = MagicMock()
    reversal_factory = MagicMock()
    monitor_factory = MagicMock()
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "PaymentProcessingConfigRepository",
        _ConfigRepository,
    )
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "ReversalJobWorker",
        reversal_factory,
    )
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "StaleProcessingJobMonitor",
        monitor_factory,
    )
    iteration = embedded_recovery_iteration.create_embedded_recovery_iteration(
        settings=Settings(),
        session_factory=lambda: session,
        gateway_factory=lambda: gateway,
    )

    assert iteration(lambda: True) == 2.5

    reversal_factory.assert_not_called()
    monitor_factory.assert_not_called()
    session.close.assert_called_once_with()
    gateway.close.assert_called_once_with()


def test_iteration_closes_resources_when_recovery_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    session = MagicMock()
    gateway = MagicMock()
    reversal = MagicMock()
    reversal.run_once.side_effect = RuntimeError("gateway unavailable")
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "PaymentProcessingConfigRepository",
        _ConfigRepository,
    )
    monkeypatch.setattr(
        embedded_recovery_iteration,
        "ReversalJobWorker",
        lambda **_kwargs: reversal,
    )
    iteration = embedded_recovery_iteration.create_embedded_recovery_iteration(
        settings=Settings(),
        session_factory=lambda: session,
        gateway_factory=lambda: gateway,
    )

    with pytest.raises(RuntimeError, match="gateway unavailable"):
        iteration(lambda: False)

    session.rollback.assert_called_once_with()
    session.close.assert_called_once_with()
    gateway.close.assert_called_once_with()


@pytest.mark.parametrize("value", [Decimal("0"), Decimal("-1")])
def test_poll_interval_must_be_positive(value: Decimal) -> None:
    with pytest.raises(ValueError, match="poll interval"):
        embedded_recovery_iteration._positive_seconds(value)
