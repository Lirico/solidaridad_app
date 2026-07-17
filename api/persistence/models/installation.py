from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from persistence.models.base import Base


class Installation(Base):
    __tablename__ = "installations"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    platform: Mapped[str | None] = mapped_column(String(64), nullable=True)
    terminal_id: Mapped[str | None] = mapped_column(String(8), nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
