"""Validated snapshots of persisted payment processing policy."""

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class PaymentProcessingConfig:
    id: int
    config_name: str
    max_authorization_attempts: int
    authorization_initial_delay_ms: int
    authorization_max_delay_ms: int
    authorization_backoff_multiplier: Decimal
    max_reversal_attempts: int
    reversal_initial_delay_seconds: int
    reversal_max_delay_seconds: int
    reversal_backoff_multiplier: Decimal
    jitter_percentage: int
    processing_timeout_seconds: int
    worker_poll_interval_seconds: Decimal
    created_at: datetime
    updated_at: datetime

    def __post_init__(self) -> None:
        if not self.config_name:
            raise ValueError("config_name must not be empty")
        if self.max_authorization_attempts < 1:
            raise ValueError("max_authorization_attempts must be at least 1")
        if self.authorization_initial_delay_ms < 0:
            raise ValueError("authorization_initial_delay_ms must not be negative")
        if self.authorization_max_delay_ms < self.authorization_initial_delay_ms:
            raise ValueError(
                "authorization_max_delay_ms must be at least the initial delay"
            )
        if self.authorization_backoff_multiplier < 1:
            raise ValueError("authorization_backoff_multiplier must be at least 1")
        if self.max_reversal_attempts < 1:
            raise ValueError("max_reversal_attempts must be at least 1")
        if self.reversal_initial_delay_seconds < 0:
            raise ValueError("reversal_initial_delay_seconds must not be negative")
        if self.reversal_max_delay_seconds < self.reversal_initial_delay_seconds:
            raise ValueError(
                "reversal_max_delay_seconds must be at least the initial delay"
            )
        if self.reversal_backoff_multiplier < 1:
            raise ValueError("reversal_backoff_multiplier must be at least 1")
        if not 0 <= self.jitter_percentage <= 100:
            raise ValueError("jitter_percentage must be between 0 and 100")
        if self.processing_timeout_seconds <= 0:
            raise ValueError("processing_timeout_seconds must be positive")
        if self.worker_poll_interval_seconds <= 0:
            raise ValueError("worker_poll_interval_seconds must be positive")

