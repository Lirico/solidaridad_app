"""Terminal device ORM model."""

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Identity, String, func
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class TerminalDevice(Base):
    __tablename__ = "terminal_devices"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    logical_device_id: Mapped[str] = mapped_column(
        String(128),
        nullable=False,
        unique=True,
    )
    installation_id: Mapped[str] = mapped_column(
        String(8),
        nullable=False,
        unique=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
