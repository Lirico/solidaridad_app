"""HTTP contract tests for POST /v1/auth/register."""

from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.auth.register_user import RegisterResult, RegisterUser
from domain.exceptions import EmailAlreadyExists, WeakPassword
from main import app
from presentation.dependencies import get_register_user

client = TestClient(app)


def _override_register_user(use_case: RegisterUser) -> None:
    app.dependency_overrides[get_register_user] = lambda: use_case


def _clear_overrides() -> None:
    app.dependency_overrides.clear()


def test_register_returns_201_and_token_shape() -> None:
    use_case = MagicMock(spec=RegisterUser)
    use_case.execute.return_value = RegisterResult(
        name="Ada",
        email="ada@example.com",
        token="jwt-token",
        must_change_password=False,
    )
    _override_register_user(use_case)

    try:
        response = client.post(
            "/v1/auth/register",
            json={
                "name": "Ada",
                "email": "ada@example.com",
                "password": "password1",
                "installation_id": "inst-1",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 201
    assert response.json() == {
        "name": "Ada",
        "email": "ada@example.com",
        "token": "jwt-token",
        "must_change_password": False,
    }
    use_case.execute.assert_called_once_with(
        name="Ada",
        email="ada@example.com",
        password="password1",
        installation_id="inst-1",
    )


def test_register_returns_409_when_email_exists() -> None:
    use_case = MagicMock(spec=RegisterUser)
    use_case.execute.side_effect = EmailAlreadyExists("ada@example.com")
    _override_register_user(use_case)

    try:
        response = client.post(
            "/v1/auth/register",
            json={
                "name": "Ada",
                "email": "ada@example.com",
                "password": "password1",
                "installation_id": "inst-1",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 409
    assert response.json() == {"message": "El email ya está registrado"}


def test_register_returns_400_when_password_weak_from_use_case() -> None:
    use_case = MagicMock(spec=RegisterUser)
    use_case.execute.side_effect = WeakPassword()
    _override_register_user(use_case)

    try:
        response = client.post(
            "/v1/auth/register",
            json={
                "name": "Ada",
                "email": "ada@example.com",
                "password": "password1",
                "installation_id": "inst-1",
            },
        )
    finally:
        _clear_overrides()

    assert response.status_code == 400
    assert response.json() == {
        "message": "La contraseña debe tener al menos 8 caracteres"
    }


def test_register_returns_400_when_installation_id_missing() -> None:
    response = client.post(
        "/v1/auth/register",
        json={
            "name": "Ada",
            "email": "ada@example.com",
            "password": "password1",
        },
    )

    assert response.status_code == 400
    assert "message" in response.json()


def test_register_returns_400_when_email_invalid() -> None:
    response = client.post(
        "/v1/auth/register",
        json={
            "name": "Ada",
            "email": "not-an-email",
            "password": "password1",
            "installation_id": "inst-1",
        },
    )

    assert response.status_code == 400
    assert "message" in response.json()
