"""Unit tests for JWT TokenService."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
import pytest

from application.auth.token_service import TokenService
from config import Settings


def _settings(**overrides: object) -> Settings:
    base = {
        "jwt_secret": "test-secret-key-for-unit-tests-32b!",
        "jwt_algorithm": "HS256",
        "jwt_expire_minutes": 60,
    }
    base.update(overrides)
    return Settings(**base)  # type: ignore[arg-type]


def test_create_access_token_includes_required_claims() -> None:
    service = TokenService(_settings())
    user_id = uuid4()

    token = service.create_access_token(
        user_id=user_id,
        email="ada@example.com",
        installation_id="inst-1",
    )

    payload = jwt.decode(
        token,
        "test-secret-key-for-unit-tests-32b!",
        algorithms=["HS256"],
    )
    assert payload["sub"] == str(user_id)
    assert payload["email"] == "ada@example.com"
    assert payload["installation_id"] == "inst-1"
    assert "jti" in payload
    assert "iat" in payload
    assert "exp" in payload


def test_verify_rejects_tampered_token() -> None:
    service = TokenService(_settings())
    token = service.create_access_token(
        user_id=uuid4(),
        email="ada@example.com",
        installation_id="inst-1",
    )
    tampered = token[:-4] + ("AAAA" if not token.endswith("AAAA") else "BBBB")

    with pytest.raises(jwt.PyJWTError):
        service.verify(tampered)


def test_verify_rejects_expired_token() -> None:
    service = TokenService(_settings(jwt_expire_minutes=-1))
    token = service.create_access_token(
        user_id=uuid4(),
        email="ada@example.com",
        installation_id="inst-1",
    )

    # Force clock skew aside: craft an already-expired token explicitly.
    expired = jwt.encode(
        {
            "sub": str(uuid4()),
            "email": "ada@example.com",
            "installation_id": "inst-1",
            "jti": "jti",
            "iat": datetime.now(UTC) - timedelta(hours=2),
            "exp": datetime.now(UTC) - timedelta(hours=1),
        },
        "test-secret-key-for-unit-tests-32b!",
        algorithm="HS256",
    )

    with pytest.raises(jwt.ExpiredSignatureError):
        service.verify(expired)

    # Also cover expire_minutes=-1 issued token if library treats it as expired.
    with pytest.raises(jwt.PyJWTError):
        service.verify(token)
