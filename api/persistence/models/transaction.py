"""Transaction ORM model."""

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    DateTime,
    ForeignKey,
    Identity,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_transactions_user_idempotency",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    transaction_number: Mapped[str] = mapped_column(
        String(14),
        nullable=False,
        unique=True,
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id"),
        nullable=False,
    )
    installation_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("installations.id"),
        nullable=False,
    )
    terminal_id: Mapped[str] = mapped_column(String(8), nullable=False)
    product: Mapped[str] = mapped_column(String(32), nullable=False)
    processor_product_code: Mapped[str] = mapped_column(String(3), nullable=False)
    amount_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    card_last4: Mapped[str] = mapped_column(String(4), nullable=False)
    stan: Mapped[str | None] = mapped_column(String(6), nullable=True)
    auth_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    retrieval_reference: Mapped[str | None] = mapped_column(
        String(32),
        nullable=True,
    )
    processor_response_code: Mapped[str | None] = mapped_column(
        String(8),
        nullable=True,
    )
    user_message: Mapped[str | None] = mapped_column(String(512), nullable=True)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    request_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
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


class TransactionNumberCounter(Base):
    __tablename__ = "transaction_number_counters"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_date: Mapped[date] = mapped_column(Date, nullable=False, unique=True)
    last_value: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
