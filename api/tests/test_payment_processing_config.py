from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

from domain.payment_processing_config import PaymentProcessingConfig
from persistence.models.payment_processing_config import (
    PaymentProcessingConfig as PaymentProcessingConfigModel,
)
from persistence.repositories.payment_processing_config_repository import (
    PaymentProcessingConfigRepository,
)


def _values() -> dict[str, object]:
    now = datetime.now(UTC)
    return {
        "id": 1,
        "config_name": "default",
        "max_authorization_attempts": 3,
        "authorization_initial_delay_ms": 100,
        "authorization_max_delay_ms": 500,
        "authorization_backoff_multiplier": Decimal("2"),
        "max_reversal_attempts": 5,
        "reversal_initial_delay_seconds": 5,
        "reversal_max_delay_seconds": 300,
        "reversal_backoff_multiplier": Decimal("2"),
        "jitter_percentage": 20,
        "processing_timeout_seconds": 60,
        "worker_poll_interval_seconds": Decimal("1"),
        "created_at": now,
        "updated_at": now,
    }


def _row() -> MagicMock:
    row = MagicMock(spec=PaymentProcessingConfigModel)
    for name, value in _values().items():
        setattr(row, name, value)
    return row


def test_repository_reads_consistent_default_snapshot() -> None:
    session = MagicMock()
    session.scalar.return_value = _row()

    config = PaymentProcessingConfigRepository(session).get_default()

    assert config.config_name == "default"
    assert config.max_authorization_attempts == 3
    assert config.max_reversal_attempts == 5
    assert config.worker_poll_interval_seconds == Decimal("1")


def test_repository_reports_missing_default() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    with pytest.raises(RuntimeError, match="default.*missing"):
        PaymentProcessingConfigRepository(session).get_default()


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("config_name", "", "config_name"),
        ("max_authorization_attempts", 0, "max_authorization_attempts"),
        ("authorization_initial_delay_ms", -1, "initial_delay"),
        ("authorization_max_delay_ms", 99, "authorization_max_delay"),
        ("authorization_backoff_multiplier", Decimal("0.9"), "backoff"),
        ("max_reversal_attempts", 0, "max_reversal_attempts"),
        ("reversal_initial_delay_seconds", -1, "initial_delay"),
        ("reversal_max_delay_seconds", 4, "reversal_max_delay"),
        ("reversal_backoff_multiplier", Decimal("0.9"), "backoff"),
        ("jitter_percentage", 101, "jitter_percentage"),
        ("processing_timeout_seconds", 0, "processing_timeout"),
        ("worker_poll_interval_seconds", Decimal("0"), "poll_interval"),
    ],
)
def test_config_rejects_invalid_values(
    field: str,
    value: object,
    message: str,
) -> None:
    values = _values()
    values[field] = value

    with pytest.raises(ValueError, match=message):
        PaymentProcessingConfig(**values)  # type: ignore[arg-type]

