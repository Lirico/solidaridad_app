"""FastAPI dependency injection wiring."""

from collections.abc import Generator
from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from application.auth.login_user import LoginUser
from application.auth.register_user import RegisterUser
from application.auth.token_service import TokenService
from config import Settings, get_settings
from persistence.database import get_db as _get_db
from persistence.repositories.installation_repository import InstallationRepository
from persistence.repositories.user_repository import UserRepository


def get_settings_dep() -> Settings:
    return get_settings()


def get_db() -> Generator[Session, None, None]:
    yield from _get_db()


def get_token_service(
    settings: Annotated[Settings, Depends(get_settings_dep)],
) -> TokenService:
    return TokenService(settings)


def get_register_user(
    db: Annotated[Session, Depends(get_db)],
    tokens: Annotated[TokenService, Depends(get_token_service)],
) -> RegisterUser:
    return RegisterUser(
        session=db,
        users=UserRepository(db),
        installations=InstallationRepository(db),
        tokens=tokens,
    )


def get_login_user(
    db: Annotated[Session, Depends(get_db)],
    tokens: Annotated[TokenService, Depends(get_token_service)],
) -> LoginUser:
    return LoginUser(
        session=db,
        users=UserRepository(db),
        installations=InstallationRepository(db),
        tokens=tokens,
    )
