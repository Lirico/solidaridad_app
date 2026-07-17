"""HTTP contract tests for POST /v1/auth/change-password."""

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import jwt
from fastapi.testclient import TestClient

from application.auth.change_password import ChangePassword
from domain.exceptions import InvalidCurrentPassword, WeakPassword
from main import app
from presentation import dependencies as deps
from presentation.dependencies import (
    CurrentUser,
    get_change_password,
    get_current_user,
)

client = TestClient(app)


def _clear_overrides() -> None:
    app.dependency_overrides.clear()


def _override_auth(
    *,
    use_case: ChangePassword | None = None,
    current_user: CurrentUser | None = None,
) -> CurrentUser:
    user = current_user or CurrentUser(
        user_id=1,
        email="ada@example.com",
        installation_id="inst-1",
    )
    app.dependency_overrides[get_current_user] = lambda: user
    if use_case is not None:
        app.dependency_overrides[get_change_password] = lambda: use_case
    return user


def test_change_password_returns_200() -> None:
    use_case = MagicMock(spec=ChangePassword)
    current = _override_auth(use_case=use_case)

    try:
        response = client.post(
            "/v1/auth/change-password",
            headers={"Authorization": "Bearer unused-because-overridden"},
            json={
                "current_password": "current12",
                "new_password": "newpass12",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert response.json() == {"message": "Contraseña actualizada correctamente"}
    use_case.execute.assert_called_once_with(
        user_id=current.user_id,
        current_password="current12",
        new_password="newpass12",
    )


def test_change_password_returns_401_when_current_password_wrong() -> None:
    use_case = MagicMock(spec=ChangePassword)
    use_case.execute.side_effect = InvalidCurrentPassword()
    _override_auth(use_case=use_case)

    try:
        response = client.post(
            "/v1/auth/change-password",
            headers={"Authorization": "Bearer unused"},
            json={
                "current_password": "wrong-pass",
                "new_password": "newpass12",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 401
    assert response.json() == {"message": "Contraseña actual incorrecta"}


def test_change_password_returns_400_when_new_equals_current() -> None:
    use_case = MagicMock(spec=ChangePassword)
    use_case.execute.side_effect = WeakPassword(
        "La nueva contraseña debe ser distinta a la actual",
    )
    _override_auth(use_case=use_case)

    try:
        response = client.post(
            "/v1/auth/change-password",
            headers={"Authorization": "Bearer unused"},
            json={
                "current_password": "samepass1",
                "new_password": "samepass1",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 400
    assert response.json() == {
        "message": "La nueva contraseña debe ser distinta a la actual"
    }


def test_change_password_returns_401_when_bearer_missing() -> None:
    response = client.post(
        "/v1/auth/change-password",
        json={
            "current_password": "current12",
            "new_password": "newpass12",
        },
    )

    assert response.status_code == 401
    assert response.json() == {"message": "Autenticación requerida"}


def test_change_password_returns_401_when_token_expired() -> None:
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

    tokens = MagicMock()
    tokens.verify.side_effect = jwt.ExpiredSignatureError("expired")
    app.dependency_overrides[deps.get_token_service] = lambda: tokens
    app.dependency_overrides[deps.get_db] = lambda: MagicMock()

    try:
        response = client.post(
            "/v1/auth/change-password",
            headers={"Authorization": f"Bearer {expired}"},
            json={
                "current_password": "current12",
                "new_password": "newpass12",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 401
    assert response.json() == {"message": "Token inválido o expirado"}
