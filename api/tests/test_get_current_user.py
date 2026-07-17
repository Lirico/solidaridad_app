"""Tests for Bearer dependency get_current_user."""

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import jwt
import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from application.auth.token_service import TokenService
from config import Settings
from domain.user import User
from presentation.dependencies import get_current_user


def _settings() -> Settings:
    return Settings(
        jwt_secret="test-secret-key-for-unit-tests-32b!",
        jwt_algorithm="HS256",
        jwt_expire_minutes=60,
    )


def _user(*, user_id: int = 1) -> User:
    now = datetime.now(UTC)
    return User(
        id=user_id,
        name="Ada",
        email="ada@example.com",
        password_hash="hash",
        must_change_password=False,
        created_at=now,
        updated_at=now,
    )


def test_get_current_user_returns_claims_from_valid_token(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    tokens = TokenService(_settings())
    user = _user()
    token = tokens.create_access_token(
        user_id=user.id,
        email=user.email,
        installation_id="inst-1",
    )
    db = MagicMock()
    repo = MagicMock()
    repo.get_by_id.return_value = user
    monkeypatch.setattr(
        "presentation.dependencies.UserRepository",
        lambda _db: repo,
    )

    current = get_current_user(
        credentials=HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials=token,
        ),
        tokens=tokens,
        db=db,
    )

    assert current.user_id == user.id
    assert current.email == user.email
    assert current.installation_id == "inst-1"


def test_get_current_user_rejects_missing_credentials() -> None:
    with pytest.raises(HTTPException) as exc_info:
        get_current_user(
            credentials=None,
            tokens=TokenService(_settings()),
            db=MagicMock(),
        )

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Autenticación requerida"


def test_get_current_user_rejects_malformed_token() -> None:
    with pytest.raises(HTTPException) as exc_info:
        get_current_user(
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer",
                credentials="not-a-jwt",
            ),
            tokens=TokenService(_settings()),
            db=MagicMock(),
        )

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Token inválido o expirado"


def test_get_current_user_rejects_expired_token() -> None:
    expired = jwt.encode(
        {
            "sub": "1",
            "email": "ada@example.com",
            "installation_id": "inst-1",
            "jti": "jti",
            "iat": datetime.now(UTC) - timedelta(hours=2),
            "exp": datetime.now(UTC) - timedelta(hours=1),
        },
        "test-secret-key-for-unit-tests-32b!",
        algorithm="HS256",
    )

    with pytest.raises(HTTPException) as exc_info:
        get_current_user(
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer",
                credentials=expired,
            ),
            tokens=TokenService(_settings()),
            db=MagicMock(),
        )

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Token inválido o expirado"


def test_get_current_user_rejects_unknown_user(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    tokens = TokenService(_settings())
    user_id = 999
    token = tokens.create_access_token(
        user_id=user_id,
        email="ghost@example.com",
        installation_id="inst-1",
    )
    repo = MagicMock()
    repo.get_by_id.return_value = None
    monkeypatch.setattr(
        "presentation.dependencies.UserRepository",
        lambda _db: repo,
    )

    with pytest.raises(HTTPException) as exc_info:
        get_current_user(
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer",
                credentials=token,
            ),
            tokens=tokens,
            db=MagicMock(),
        )

    assert exc_info.value.status_code == 401
