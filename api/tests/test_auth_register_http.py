"""Account provisioning is not exposed via public HTTP."""

from fastapi.testclient import TestClient

from main import app


def test_public_registration_endpoint_does_not_exist() -> None:
    response = TestClient(app).post(
        "/v1/auth/register",
        json={
            "name": "Ada",
            "email": "ada@example.com",
            "password": "password1",
            "installation_id": "inst-1",
        },
    )
    assert response.status_code == 404
