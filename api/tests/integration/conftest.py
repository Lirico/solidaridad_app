"""Fixtures for black-box tests against an already running API."""

import os
from collections.abc import Callable, Generator
from dataclasses import dataclass
from uuid import uuid4

import httpx
import pytest
from pwdlib import PasswordHash
from sqlalchemy import create_engine, text


@dataclass(frozen=True, slots=True)
class Operator:
    token: str
    email: str
    password: str
    installation_id: str

    @property
    def headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}


@pytest.fixture(scope="session")
def api_base_url() -> str:
    return os.environ.get("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")


@pytest.fixture(scope="session")
def gateway_control_url() -> str:
    return os.environ.get(
        "INTEGRATION_GATEWAY_CONTROL_URL", "http://127.0.0.1:8011"
    ).rstrip("/")


@pytest.fixture(scope="session")
def api(api_base_url: str) -> Generator[httpx.Client, None, None]:
    with httpx.Client(base_url=api_base_url, timeout=10) as client:
        try:
            response = client.get("/health/live")
        except httpx.HTTPError as exc:
            pytest.fail(f"API_BASE_URL is not reachable: {api_base_url}: {exc}")
        if response.status_code != 200:
            pytest.fail(
                f"API_BASE_URL did not pass liveness: {response.status_code} "
                f"{response.text}"
            )
        yield client


@pytest.fixture
def gateway(gateway_control_url: str) -> Generator[httpx.Client, None, None]:
    with httpx.Client(base_url=gateway_control_url, timeout=10) as client:
        try:
            response = client.post("/__test__/reset")
        except httpx.HTTPError as exc:
            pytest.fail(
                "The gateway control service is not reachable at "
                f"{gateway_control_url}: {exc}"
            )
        if response.status_code != 200:
            pytest.fail(f"Gateway reset failed: {response.status_code} {response.text}")
        yield client


@pytest.fixture
def make_operator(api: httpx.Client) -> Callable[..., Operator]:
    def _make(
        *, installation_id: str | None = None, merchant_code: str | None = None
    ) -> Operator:
        unique = uuid4().hex
        password = "integration-password-123"
        terminal = installation_id or f"I{unique[:7]}"
        database_url = os.environ.get("INTEGRATION_DATABASE_URL")
        if not database_url:
            pytest.fail(
                "Set INTEGRATION_DATABASE_URL to the dedicated integration database"
            )
        email = f"integration-{unique}@example.com"
        engine = create_engine(database_url)
        try:
            with engine.begin() as connection:
                code = merchant_code or unique[:15]
                connection.execute(
                    text(
                        "INSERT INTO merchants (code, name, address, city, tax_id) "
                        "VALUES (:code, 'Test', 'Test', 'Test', 'Test') "
                        "ON CONFLICT (code) DO NOTHING"
                    ),
                    {"code": code},
                )
                merchant_id = connection.scalar(
                    text("SELECT id FROM merchants WHERE code = :code"), {"code": code}
                )
                connection.execute(
                    text(
                        "INSERT INTO users (merchant_id, name, email, password_hash, "
                        "must_change_password) VALUES (:merchant_id, "
                        "'Integration Operator', "
                        ":email, :password_hash, false)"
                    ),
                    {
                        "merchant_id": merchant_id,
                        "email": email,
                        "password_hash": PasswordHash.recommended().hash(password),
                    },
                )
        finally:
            engine.dispose()
        response = api.post(
            "/v1/auth/login",
            json={
                "username": email,
                "password": password,
                "installation_id": terminal,
            },
        )
        assert response.status_code == 200, response.text
        return Operator(
            token=response.json()["token"],
            email=response.json()["email"],
            password=password,
            installation_id=terminal,
        )

    return _make


@pytest.fixture
def sale_payload() -> dict[str, str]:
    return {
        "product": "GARRAFA_10",
        "amount": "2",
        "card_number": "6063007014007403",
        "expiration_date": "2912",
        "cvv": "123",
    }


def set_gateway_scenario(
    gateway: httpx.Client,
    route: str,
    *replies: dict[str, object],
) -> None:
    response = gateway.post(
        "/__test__/scenario",
        json={"route": route, "replies": list(replies)},
    )
    assert response.status_code == 200, response.text


def gateway_requests(gateway: httpx.Client, route: str) -> list[dict[str, object]]:
    response = gateway.get("/__test__/requests")
    assert response.status_code == 200, response.text
    return [item for item in response.json()["items"] if item["route"] == route]
