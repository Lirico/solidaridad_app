"""HTTP contract tests for POST /v1/auth/login."""

from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.auth.login_user import LoginResult, LoginUser
from domain.exceptions import InvalidCredentials
from main import app
from presentation.dependencies import get_login_user

client = TestClient(app)


def _override_login_user(use_case: LoginUser) -> None:
    app.dependency_overrides[get_login_user] = lambda: use_case


def _clear_overrides() -> None:
    app.dependency_overrides.clear()


def test_login_returns_200_and_token_shape() -> None:
    use_case = MagicMock(spec=LoginUser)
    use_case.execute.return_value = LoginResult(
        name="Ada",
        email="ada@example.com",
        token="jwt-token",
        must_change_password=True,
    )
    _override_login_user(use_case)

    try:
        response = client.post(
            "/v1/auth/login",
            json={
                "username": "ada@example.com",
                "password": "password1",
                "installation_id": "inst-1",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert response.json() == {
        "name": "Ada",
        "email": "ada@example.com",
        "token": "jwt-token",
        "must_change_password": True,
    }
    use_case.execute.assert_called_once_with(
        username="ada@example.com",
        password="password1",
        installation_id="inst-1",
    )


def test_login_returns_401_on_invalid_credentials() -> None:
    use_case = MagicMock(spec=LoginUser)
    use_case.execute.side_effect = InvalidCredentials()
    _override_login_user(use_case)

    try:
        response = client.post(
            "/v1/auth/login",
            json={
                "username": "ada@example.com",
                "password": "wrong-pass",
                "installation_id": "inst-1",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 401
    assert response.json() == {"message": "Credenciales inválidas"}


def test_login_returns_400_when_installation_id_missing() -> None:
    response = client.post(
        "/v1/auth/login",
        json={
            "username": "ada@example.com",
            "password": "password1",
        },
    )

    assert response.status_code == 400
    assert "message" in response.json()


def test_login_returns_400_when_installation_id_is_blank() -> None:
    response = client.post(
        "/v1/auth/login",
        json={
            "username": "ada@example.com",
            "password": "password1",
            "installation_id": "   ",
        },
    )

    assert response.status_code == 400
    assert "message" in response.json()


def test_login_returns_400_when_installation_id_exceeds_8_characters() -> None:
    response = client.post(
        "/v1/auth/login",
        json={
            "username": "ada@example.com",
            "password": "password1",
            "installation_id": "123456789",
        },
    )

    assert response.status_code == 400
    assert "message" in response.json()
