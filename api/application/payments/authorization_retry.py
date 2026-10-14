"""Safe synchronous retry policy for payment authorizations."""

import random
from collections.abc import Callable
from dataclasses import dataclass

from domain.payment_processing_config import PaymentProcessingConfig


@dataclass(frozen=True, slots=True)
class AuthorizationRetryPolicy:
    """Immutable authorization policy built from one config snapshot."""

    max_attempts: int
    initial_delay_ms: int
    max_delay_ms: int
    backoff_multiplier: float
    jitter_percentage: int
    processing_timeout_seconds: int
    random_value: Callable[[], float] = random.random

    @classmethod
    def from_config(
        cls,
        config: PaymentProcessingConfig,
        *,
        random_value: Callable[[], float] = random.random,
    ) -> "AuthorizationRetryPolicy":
        return cls(
            max_attempts=config.max_authorization_attempts,
            initial_delay_ms=config.authorization_initial_delay_ms,
            max_delay_ms=config.authorization_max_delay_ms,
            backoff_multiplier=float(config.authorization_backoff_multiplier),
            jitter_percentage=config.jitter_percentage,
            processing_timeout_seconds=config.processing_timeout_seconds,
            random_value=random_value,
        )

    def delay_before_attempt(self, attempt_number: int) -> float:
        """Return seconds to wait before an additional attempt.

        Attempt one is immediate. Jitter is symmetric and the configured
        maximum caps the final delay as well as the exponential base.
        """
        if attempt_number <= 1:
            return 0.0
        retry_index = attempt_number - 2
        base_ms = min(
            self.initial_delay_ms * self.backoff_multiplier**retry_index,
            self.max_delay_ms,
        )
        jitter_ratio = self.jitter_percentage / 100
        jitter_factor = 1 + ((self.random_value() * 2) - 1) * jitter_ratio
        delay_ms = min(max(base_ms * jitter_factor, 0), self.max_delay_ms)
        return delay_ms / 1000
