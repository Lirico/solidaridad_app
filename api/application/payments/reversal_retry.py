"""Retry timing policy for durable reversal jobs."""

import random
from collections.abc import Callable
from dataclasses import dataclass

from domain.payment_processing_config import PaymentProcessingConfig


@dataclass(frozen=True, slots=True)
class ReversalRetryPolicy:
    """Immutable retry policy built from one persisted config snapshot."""

    max_attempts: int
    initial_delay_seconds: int
    max_delay_seconds: int
    backoff_multiplier: float
    jitter_percentage: int
    random_value: Callable[[], float] = random.random

    @classmethod
    def from_config(
        cls,
        config: PaymentProcessingConfig,
        *,
        random_value: Callable[[], float] = random.random,
    ) -> "ReversalRetryPolicy":
        return cls(
            max_attempts=config.max_reversal_attempts,
            initial_delay_seconds=config.reversal_initial_delay_seconds,
            max_delay_seconds=config.reversal_max_delay_seconds,
            backoff_multiplier=float(config.reversal_backoff_multiplier),
            jitter_percentage=config.jitter_percentage,
            random_value=random_value,
        )

    def delay_after_attempt(self, attempt_number: int) -> float:
        """Return seconds before retrying a definitely-unsent attempt."""
        retry_index = max(attempt_number - 1, 0)
        base_seconds = min(
            self.initial_delay_seconds * self.backoff_multiplier**retry_index,
            self.max_delay_seconds,
        )
        jitter_ratio = self.jitter_percentage / 100
        jitter_factor = 1 + ((self.random_value() * 2) - 1) * jitter_ratio
        return min(max(base_seconds * jitter_factor, 0), self.max_delay_seconds)
