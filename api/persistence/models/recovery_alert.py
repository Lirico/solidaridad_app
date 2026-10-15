"""Durable operational alert for a processor recovery case."""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class RecoveryAlert(Base):
    __tablename__ = "recovery_alerts"
    __table_args__ = (
        UniqueConstraint(
            "processor_job_id",
            "cause",
            name="uq_recovery_alerts_job_cause",
        ),
        CheckConstraint("state = 'OPEN'", name="ck_recovery_alerts_state"),
        Index("ix_recovery_alerts_opened", "state", "opened_at", "id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    processor_job_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("processor_jobs.id"),
        nullable=False,
    )
    cause: Mapped[str] = mapped_column(String(64), nullable=False)
    state: Mapped[str] = mapped_column(String(16), nullable=False)
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
