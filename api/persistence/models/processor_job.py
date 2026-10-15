"""Durable processor job ORM model."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class ProcessorJob(Base):
    __tablename__ = "processor_jobs"
    __table_args__ = (
        UniqueConstraint(
            "transaction_id",
            "operation_type",
            name="uq_processor_jobs_transaction_operation",
        ),
        UniqueConstraint(
            "transaction_id",
            "reversal_stan",
            name="uq_processor_jobs_transaction_reversal_stan",
        ),
        CheckConstraint(
            "operation_type IN ('AUTHORIZE', 'REVERSE')",
            name="ck_processor_jobs_operation_type",
        ),
        CheckConstraint(
            "state IN ('READY', 'PROCESSING', 'RETRY', 'COMPLETED', "
            "'MANUAL_REVIEW')",
            name="ck_processor_jobs_state",
        ),
        CheckConstraint("attempt_count >= 0", name="ck_processor_jobs_attempt_count"),
        CheckConstraint(
            "state <> 'PROCESSING' OR (worker_id IS NOT NULL AND "
            "claim_token IS NOT NULL AND processing_started_at IS NOT NULL)",
            name="ck_processor_jobs_processing_claim",
        ),
        CheckConstraint(
            "state <> 'COMPLETED' OR (result IS NOT NULL AND completed_at IS NOT NULL)",
            name="ck_processor_jobs_completed_result",
        ),
        Index(
            "ix_processor_jobs_available",
            "state",
            "next_attempt_at",
            "id",
            postgresql_where=text("state IN ('READY', 'RETRY')"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    transaction_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("transactions.id"),
        nullable=False,
    )
    operation_type: Mapped[str] = mapped_column(String(16), nullable=False)
    state: Mapped[str] = mapped_column(String(16), nullable=False)
    result: Mapped[str | None] = mapped_column(String(64), nullable=True)
    attempt_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    next_attempt_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    worker_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    claim_token: Mapped[UUID | None] = mapped_column(Uuid, nullable=True)
    processing_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    original_stan: Mapped[str | None] = mapped_column(String(6), nullable=True)
    original_ticket: Mapped[str | None] = mapped_column(String(24), nullable=True)
    reversal_stan: Mapped[str | None] = mapped_column(String(6), nullable=True)
    last_error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    last_error_detail_sanitized: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
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
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
