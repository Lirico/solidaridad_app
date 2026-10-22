"""Fixtures for black-box tests against an already running API."""

import os
from collections.abc import Callable, Generator
from dataclasses import dataclass
from uuid import uuid4

import httpx
import pytest


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
def make_operator(api: httpx.Client) -> Callable[[], Operator]:
    def _make() -> Operator:
        unique = uuid4().hex
        password = "integration-password-123"
        installation_id = f"I{unique[:7]}"
        response = api.post(
            "/v1/auth/register",
            json={
                "name": "Integration Operator",
                "email": f"integration-{unique}@example.com",
                "password": password,
                "installation_id": installation_id,
            },
        )
        assert response.status_code == 201, response.text
        return Operator(
            token=response.json()["token"],
            email=response.json()["email"],
            password=password,
            installation_id=installation_id,
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
