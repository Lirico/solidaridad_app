"""FastAPI dependency injection wiring."""

from collections.abc import Generator
from dataclasses import dataclass
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from application.auth.change_password import ChangePassword
from application.auth.login_user import LoginUser
from application.auth.register_user import RegisterUser
from application.auth.token_service import TokenService
from application.payments.create_transaction import CreateTransaction
from config import Settings, get_settings
from infrastructure.payments.http_gateway import HttpPaymentGateway
from persistence.database import get_db as _get_db
from persistence.repositories.installation_repository import InstallationRepository
from persistence.repositories.transaction_repository import TransactionRepository
from persistence.repositories.user_repository import UserRepository

_bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True, slots=True)
class CurrentUser:
    user_id: int
    email: str
    installation_id: str


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


def get_change_password(
    db: Annotated[Session, Depends(get_db)],
) -> ChangePassword:
    return ChangePassword(
        session=db,
        users=UserRepository(db),
    )


def get_payment_gateway(
    settings: Annotated[Settings, Depends(get_settings_dep)],
) -> HttpPaymentGateway:
    return HttpPaymentGateway(
        base_url=settings.payment_gateway_url,
        timeout_seconds=settings.payment_gateway_timeout_seconds,
    )


def get_create_transaction(
    db: Annotated[Session, Depends(get_db)],
    gateway: Annotated[HttpPaymentGateway, Depends(get_payment_gateway)],
) -> CreateTransaction:
    return CreateTransaction(
        session=db,
        transactions=TransactionRepository(db),
        installations=InstallationRepository(db),
        gateway=gateway,
    )


def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(_bearer_scheme),
    ],
    tokens: Annotated[TokenService, Depends(get_token_service)],
    db: Annotated[Session, Depends(get_db)],
) -> CurrentUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticación requerida",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        payload = tokens.verify(credentials.credentials)
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    sub = payload.get("sub")
    email = payload.get("email")
    installation_id = payload.get("installation_id")
    if not isinstance(sub, str) or not sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not isinstance(installation_id, str) or not installation_id.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not isinstance(email, str) or not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_id = int(sub)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    user = UserRepository(db).get_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return CurrentUser(
        user_id=user.id,
        email=email,
        installation_id=installation_id.strip(),
    )
