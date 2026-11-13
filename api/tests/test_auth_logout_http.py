"""HTTP contract tests for POST /v1/auth/logout."""

from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from application.auth.logout_user import LogoutUser
from main import app
from presentation.dependencies import CurrentUser, get_current_user, get_logout_user

client = TestClient(app)


def test_logout_revokes_the_account_sessions() -> None:
    use_case = MagicMock(spec=LogoutUser)
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=7,
        email="ada@example.com",
        installation_id="inst-1",
    )
    app.dependency_overrides[get_logout_user] = lambda: use_case

    try:
        response = client.post(
            "/v1/auth/logout",
            headers={"Authorization": "Bearer unused"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {"message": "Sesión cerrada"}
    use_case.execute.assert_called_once_with(user_id=7)


def test_logout_requires_a_token() -> None:
    response = client.post("/v1/auth/logout")

    assert response.status_code == 401
    assert response.json() == {"message": "Autenticación requerida"}
