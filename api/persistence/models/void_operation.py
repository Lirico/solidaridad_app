"""ORM models for durable void recovery."""

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
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class VoidOperation(Base):
    __tablename__ = "void_operations"
    __table_args__ = (
        UniqueConstraint(
            "transaction_id",
            "idempotency_key",
            name="uq_void_operations_transaction_idempotency",
        ),
        CheckConstraint(
            "outcome IN ('PENDING', 'APPROVED', 'DECLINED', 'NOT_SENT', "
            "'INDETERMINATE')",
            name="ck_void_operations_outcome",
        ),
        CheckConstraint(
            "status IN ('PENDING', 'VOIDED', 'DECLINED', 'FAILED', 'UNDER_REVIEW')",
            name="ck_void_operations_status",
        ),
        Index(
            "uq_void_operations_active_transaction",
            "transaction_id",
            unique=True,
            postgresql_where=text("status IN ('PENDING', 'UNDER_REVIEW')"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    transaction_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("transactions.id"), nullable=False
    )
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    request_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    stan: Mapped[str] = mapped_column(String(6), nullable=False)
    void_ticket: Mapped[str] = mapped_column(String(24), nullable=False)
    original_ticket: Mapped[str] = mapped_column(String(24), nullable=False)
    outcome: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    processor_response_code: Mapped[str | None] = mapped_column(
        String(8), nullable=True
    )
    user_message: Mapped[str] = mapped_column(String(512), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class VoidOperationAlert(Base):
    __tablename__ = "void_operation_alerts"
    __table_args__ = (
        UniqueConstraint(
            "void_operation_id",
            "cause",
            name="uq_void_operation_alerts_operation_cause",
        ),
        CheckConstraint("state = 'OPEN'", name="ck_void_operation_alerts_state"),
        Index("ix_void_operation_alerts_opened", "state", "opened_at", "id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    void_operation_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("void_operations.id"), nullable=False
    )
    cause: Mapped[str] = mapped_column(String(64), nullable=False)
    state: Mapped[str] = mapped_column(String(16), nullable=False)
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
