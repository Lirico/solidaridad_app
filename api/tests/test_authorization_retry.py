from datetime import UTC, datetime
from decimal import Decimal

import pytest

from application.payments.authorization_retry import AuthorizationRetryPolicy
from domain.payment_processing_config import PaymentProcessingConfig


def _config(**overrides: object) -> PaymentProcessingConfig:
    values = dict(
        id=1,
        config_name="default",
        max_authorization_attempts=4,
        authorization_initial_delay_ms=100,
        authorization_max_delay_ms=250,
        authorization_backoff_multiplier=Decimal("2"),
        max_reversal_attempts=5,
        reversal_initial_delay_seconds=5,
        reversal_max_delay_seconds=300,
        reversal_backoff_multiplier=Decimal("2"),
        jitter_percentage=20,
        processing_timeout_seconds=3,
        worker_poll_interval_seconds=Decimal("1"),
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    values.update(overrides)
    return PaymentProcessingConfig(**values)  # type: ignore[arg-type]


def test_policy_copies_config_snapshot() -> None:
    policy = AuthorizationRetryPolicy.from_config(
        _config(),
        random_value=lambda: 0.5,
    )

    assert policy.max_attempts == 4
    assert policy.processing_timeout_seconds == 3
    assert policy.delay_before_attempt(1) == 0
    assert policy.delay_before_attempt(2) == pytest.approx(0.1)
    assert policy.delay_before_attempt(3) == pytest.approx(0.2)
    assert policy.delay_before_attempt(4) == pytest.approx(0.25)


@pytest.mark.parametrize(
    ("random_value", "expected_seconds"),
    [(0.0, 0.08), (0.5, 0.1), (1.0, 0.12)],
)
def test_policy_applies_symmetric_jitter(
    random_value: float,
    expected_seconds: float,
) -> None:
    policy = AuthorizationRetryPolicy.from_config(
        _config(),
        random_value=lambda: random_value,
    )

    assert policy.delay_before_attempt(2) == pytest.approx(expected_seconds)


def test_policy_caps_jittered_delay_at_configured_maximum() -> None:
    policy = AuthorizationRetryPolicy.from_config(
        _config(
            authorization_initial_delay_ms=250,
            authorization_max_delay_ms=250,
        ),
        random_value=lambda: 1.0,
    )

    assert policy.delay_before_attempt(2) == pytest.approx(0.25)
