"""Persisted payment processing policy ORM model."""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    Identity,
    Integer,
    Numeric,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class PaymentProcessingConfig(Base):
    __tablename__ = "payment_processing_config"
    __table_args__ = (
        CheckConstraint(
            "max_authorization_attempts >= 1",
            name="ck_payment_config_max_authorization_attempts",
        ),
        CheckConstraint(
            "authorization_initial_delay_ms >= 0",
            name="ck_payment_config_authorization_initial_delay",
        ),
        CheckConstraint(
            "authorization_max_delay_ms >= authorization_initial_delay_ms",
            name="ck_payment_config_authorization_max_delay",
        ),
        CheckConstraint(
            "authorization_backoff_multiplier >= 1",
            name="ck_payment_config_authorization_backoff",
        ),
        CheckConstraint(
            "max_reversal_attempts >= 1",
            name="ck_payment_config_max_reversal_attempts",
        ),
        CheckConstraint(
            "reversal_initial_delay_seconds >= 0",
            name="ck_payment_config_reversal_initial_delay",
        ),
        CheckConstraint(
            "reversal_max_delay_seconds >= reversal_initial_delay_seconds",
            name="ck_payment_config_reversal_max_delay",
        ),
        CheckConstraint(
            "reversal_backoff_multiplier >= 1",
            name="ck_payment_config_reversal_backoff",
        ),
        CheckConstraint(
            "jitter_percentage BETWEEN 0 AND 100",
            name="ck_payment_config_jitter_percentage",
        ),
        CheckConstraint(
            "processing_timeout_seconds > 0",
            name="ck_payment_config_processing_timeout",
        ),
        CheckConstraint(
            "worker_poll_interval_seconds > 0",
            name="ck_payment_config_worker_poll_interval",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    config_name: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        unique=True,
    )
    max_authorization_attempts: Mapped[int] = mapped_column(Integer, nullable=False)
    authorization_initial_delay_ms: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    authorization_max_delay_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    authorization_backoff_multiplier: Mapped[Decimal] = mapped_column(
        Numeric(10, 4),
        nullable=False,
    )
    max_reversal_attempts: Mapped[int] = mapped_column(Integer, nullable=False)
    reversal_initial_delay_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    reversal_max_delay_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    reversal_backoff_multiplier: Mapped[Decimal] = mapped_column(
        Numeric(10, 4),
        nullable=False,
    )
    jitter_percentage: Mapped[int] = mapped_column(Integer, nullable=False)
    processing_timeout_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    worker_poll_interval_seconds: Mapped[Decimal] = mapped_column(
        Numeric(10, 4),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
