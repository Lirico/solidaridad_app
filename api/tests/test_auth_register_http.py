"""HTTP contract for registration while accounts are provisioned manually."""

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_register_is_disabled_until_a_merchant_can_be_assigned() -> None:
    response = client.post(
        "/v1/auth/register",
        json={
            "name": "Ada",
            "email": "ada@example.com",
            "password": "password1",
            "installation_id": "inst-1",
        },
    )
    assert response.status_code == 403
    assert "token" not in response.json()


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


def test_register_returns_400_when_installation_id_is_blank() -> None:
    response = client.post(
        "/v1/auth/register",
        json={
            "name": "Ada",
            "email": "ada@example.com",
            "password": "password1",
            "installation_id": "   ",
        },
    )

    assert response.status_code == 400
    assert "message" in response.json()


def test_register_returns_400_when_installation_id_exceeds_8_characters() -> None:
    response = client.post(
        "/v1/auth/register",
        json={
            "name": "Ada",
            "email": "ada@example.com",
            "password": "password1",
            "installation_id": "123456789",
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
