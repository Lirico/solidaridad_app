"""Administrative batch-close ORM model."""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Identity,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class BatchClose(Base):
    __tablename__ = "batch_closes"
    __table_args__ = (
        UniqueConstraint(
            "installation_id",
            "idempotency_key",
            name="uq_batch_closes_installation_idempotency",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    installation_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("installations.id"),
        nullable=False,
    )
    terminal_id: Mapped[str] = mapped_column(String(8), nullable=False)
    closed_by_user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id"),
        nullable=False,
    )
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    closed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
