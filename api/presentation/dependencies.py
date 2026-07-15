"""FastAPI dependency injection wiring."""

from collections.abc import Generator

from sqlalchemy.orm import Session

from config import Settings, get_settings
from persistence.database import get_db as _get_db


def get_settings_dep() -> Settings:
    return get_settings()


def get_db() -> Generator[Session, None, None]:
    yield from _get_db()
