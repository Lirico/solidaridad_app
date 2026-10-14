from datetime import UTC, datetime
from decimal import Decimal

import pytest

from application.payments.reversal_retry import ReversalRetryPolicy
from domain.payment_processing_config import PaymentProcessingConfig


def _config(**overrides: object) -> PaymentProcessingConfig:
    now = datetime.now(UTC)
    values = {
        "id": 1,
        "config_name": "default",
        "max_authorization_attempts": 3,
        "authorization_initial_delay_ms": 100,
        "authorization_max_delay_ms": 500,
        "authorization_backoff_multiplier": Decimal("2"),
        "max_reversal_attempts": 3,
        "reversal_initial_delay_seconds": 5,
        "reversal_max_delay_seconds": 30,
        "reversal_backoff_multiplier": Decimal("2"),
        "jitter_percentage": 20,
        "processing_timeout_seconds": 60,
        "worker_poll_interval_seconds": Decimal("1"),
        "created_at": now,
        "updated_at": now,
    }
    values.update(overrides)
    return PaymentProcessingConfig(**values)  # type: ignore[arg-type]


@pytest.mark.parametrize(
    ("attempt_number", "random_value", "expected"),
    [
        (1, 0.5, 5),
        (2, 1.0, 12),
        (3, 0.0, 16),
        (5, 0.5, 30),
    ],
)
def test_reversal_retry_delay_uses_backoff_jitter_and_cap(
    attempt_number: int,
    random_value: float,
    expected: float,
) -> None:
    policy = ReversalRetryPolicy.from_config(
        _config(),
        random_value=lambda: random_value,
    )

    assert policy.delay_after_attempt(attempt_number) == expected
