"""Read persisted payment processing policy snapshots."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.payment_processing_config import PaymentProcessingConfig
from persistence.models.payment_processing_config import (
    PaymentProcessingConfig as PaymentProcessingConfigModel,
)


def _to_domain(row: PaymentProcessingConfigModel) -> PaymentProcessingConfig:
    return PaymentProcessingConfig(
        id=row.id,
        config_name=row.config_name,
        max_authorization_attempts=row.max_authorization_attempts,
        authorization_initial_delay_ms=row.authorization_initial_delay_ms,
        authorization_max_delay_ms=row.authorization_max_delay_ms,
        authorization_backoff_multiplier=row.authorization_backoff_multiplier,
        max_reversal_attempts=row.max_reversal_attempts,
        reversal_initial_delay_seconds=row.reversal_initial_delay_seconds,
        reversal_max_delay_seconds=row.reversal_max_delay_seconds,
        reversal_backoff_multiplier=row.reversal_backoff_multiplier,
        jitter_percentage=row.jitter_percentage,
        processing_timeout_seconds=row.processing_timeout_seconds,
        worker_poll_interval_seconds=row.worker_poll_interval_seconds,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


class PaymentProcessingConfigRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_name(self, config_name: str) -> PaymentProcessingConfig | None:
        row = self._session.scalar(
            select(PaymentProcessingConfigModel).where(
                PaymentProcessingConfigModel.config_name == config_name
            )
        )
        return _to_domain(row) if row is not None else None

    def get_default(self) -> PaymentProcessingConfig:
        config = self.get_by_name("default")
        if config is None:
            raise RuntimeError("payment processing config 'default' is missing")
        return config

