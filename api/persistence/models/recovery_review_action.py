"""Immutable audit records for central recovery review actions."""

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, String, func
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class RecoveryReviewAction(Base):
    __tablename__ = "recovery_review_actions"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    processor_job_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("processor_jobs.id"),
        nullable=False,
    )
    operator_user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id"),
        nullable=False,
    )
    action_type: Mapped[str] = mapped_column(String(32), nullable=False)
    resolution: Mapped[str | None] = mapped_column(String(64), nullable=True)
    reason: Mapped[str] = mapped_column(String(512), nullable=False)
    external_reference: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
