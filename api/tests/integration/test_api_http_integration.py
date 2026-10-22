"""High-value HTTP scenarios through the deployed API and real persistence."""

from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import httpx
import pytest

from tests.integration.conftest import gateway_requests, set_gateway_scenario


def _sale(
    api: httpx.Client,
    headers: dict[str, str],
    payload: dict[str, str],
    key: str | None = None,
) -> httpx.Response:
    request_headers = headers.copy()
    if key is not None:
        request_headers["Idempotency-Key"] = key
    return api.post("/v1/transactions", headers=request_headers, json=payload)


def test_health_cors_and_error_shape(api: httpx.Client) -> None:
    assert api.get("/ping").json() == {"status": "ok"}
    assert api.get("/health/live").status_code == 200
    preflight = api.options(
        "/v1/transactions",
        headers={
            "Origin": "https://terminal.example.test",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert preflight.status_code == 200
    assert preflight.headers["access-control-allow-origin"] == "https://terminal.example.test"
    invalid = api.post("/v1/auth/login", content="{")
    assert invalid.status_code == 400
    assert set(invalid.json()) == {"message"}


def test_auth_register_login_change_password_and_rejections(
    api: httpx.Client, make_operator: object
) -> None:
    make = make_operator
    assert callable(make)
    operator = make()
    valid_login = api.post(
        "/v1/auth/login",
        json={
            "username": operator.email,
            "password": operator.password,
            "installation_id": operator.installation_id,
        },
    )
    assert valid_login.status_code == 200
    assert valid_login.json()["email"] == operator.email
    duplicate = api.post(
        "/v1/auth/register",
        json={
            "name": "Integration Operator",
            "email": operator.email,
            "password": operator.password,
            "installation_id": operator.installation_id,
        },
    )
    assert duplicate.status_code == 409
    wrong_login = api.post(
        "/v1/auth/login",
        json={
            "username": "missing@example.test",
            "password": "wrong-password",
            "installation_id": operator.installation_id,
        },
    )
    assert wrong_login.status_code == 401
    assert wrong_login.json() == {"message": "Credenciales inválidas"}

    login = api.post(
        "/v1/auth/login",
        json={
            "username": "integration-does-not-exist@example.test",
            "password": operator.password,
            "installation_id": operator.installation_id,
        },
    )
    assert login.status_code == 401
    assert login.json() == wrong_login.json()

    changed = api.post(
        "/v1/auth/change-password",
        headers=operator.headers,
        json={
            "current_password": operator.password,
            "new_password": "new-integration-password-123",
        },
    )
    assert changed.status_code == 200
    assert changed.json() == {"message": "Contraseña actualizada correctamente"}
    old_password = api.post(
        "/v1/auth/login",
        json={
            "username": operator.email,
            "password": operator.password,
            "installation_id": operator.installation_id,
        },
    )
    assert old_password.status_code == 401
    new_password = api.post(
        "/v1/auth/login",
        json={
            "username": operator.email,
            "password": "new-integration-password-123",
            "installation_id": operator.installation_id,
        },
    )
    assert new_password.status_code == 200


@pytest.mark.parametrize(
    ("payload", "field"),
    [
        (
            {"username": "a@b.test", "password": "x", "installation_id": ""},
            "installation_id",
        ),
        (
            {
                "username": "a@b.test",
                "password": "",
                "installation_id": "TERM0001",
            },
            "password",
        ),
        (
            {
                "username": "a@b.test",
                "password": "x",
                "installation_id": "TOO-LONG9",
            },
            "installation_id",
        ),
    ],
)
def test_auth_validation_boundaries(
    api: httpx.Client, payload: dict[str, str], field: str
) -> None:
    response = api.post("/v1/auth/login", json=payload)
    assert response.status_code == 400
    assert field in response.json()["message"]


@pytest.mark.parametrize(
    "path",
    ["/v1/products", "/v1/transactions", "/v1/balance"],
)
def test_protected_endpoints_reject_missing_bearer(
    api: httpx.Client, path: str
) -> None:
    response = api.get(path) if path != "/v1/balance" else api.post(path, json={})
    assert response.status_code == 401
    assert response.json() == {"message": "Autenticación requerida"}


def test_catalog_requires_auth_and_returns_complete_contract(
    api: httpx.Client, make_operator: object
) -> None:
    make = make_operator
    assert callable(make)
    response = api.get("/v1/products", headers=make().headers)
    assert response.status_code == 200
    products = response.json()
    assert [item["code"] for item in products] == [
        "GARRAFA_10",
        "GARRAFA_15",
        "GARRAFA_30",
        "TUBO_45",
        "GRANEL",
    ]
    assert products[-1]["unit"] == {"singular": "m3", "plural": "m3"}


def test_sale_approved_replay_and_public_history(
    api: httpx.Client,
    gateway: httpx.Client,
    make_operator: object,
    sale_payload: dict[str, str],
) -> None:
    make = make_operator
    assert callable(make)
    operator = make()
    key = f"sale-{uuid4()}"
    first = _sale(api, operator.headers, sale_payload, key)
    assert first.status_code == 201, first.text
    created = first.json()
    assert created["status"] == "APPROVED"
    assert created["may_start_new_sale"] is True
    assert {"reason", "poll_after_seconds"}.issubset(created)

    replay = _sale(api, operator.headers, sale_payload, key)
    assert replay.status_code == 200
    assert replay.json()["transaction_number"] == created["transaction_number"]
    assert len(gateway_requests(gateway, "authorize")) == 1

    detail = api.get(
        f"/v1/transactions/{created['transaction_number']}", headers=operator.headers
    )
    assert detail.status_code == 200
    assert detail.json()["status"] == "APPROVED"
    listing = api.get("/v1/transactions?limit=1&offset=0", headers=operator.headers)
    assert listing.status_code == 200
    assert listing.json()["total"] == 1
    assert (
        listing.json()["items"][0]["transaction_number"]
        == created["transaction_number"]
    )

    forwarded = gateway_requests(gateway, "authorize")[0]["body"]
    assert isinstance(forwarded, dict)
    assert "cvv" not in forwarded
    for value in (sale_payload["card_number"], sale_payload["cvv"]):
        assert value not in str(created)
        assert value not in str(listing.json())


@pytest.mark.parametrize(
    "payload_update",
    [
        {"amount": "0"},
        {"amount": "1.25"},
        {"amount": "99999999999.99"},
        {"card_number": "123"},
        {"card_number": "606300701400740X"},
        {"cvv": "12"},
        {"cvv": "12345"},
        {"product": "UNKNOWN"},
    ],
)
def test_sale_validation_partitions(
    api: httpx.Client,
    make_operator: object,
    sale_payload: dict[str, str],
    payload_update: dict[str, str],
) -> None:
    make = make_operator
    assert callable(make)
    response = _sale(
        api,
        make().headers,
        sale_payload | payload_update,
        f"invalid-{uuid4()}",
    )
    assert response.status_code == 400
    assert set(response.json()) == {"message"}


def test_sale_requires_idempotency_key_and_rejects_body_conflicts(
    api: httpx.Client, make_operator: object, sale_payload: dict[str, str]
) -> None:
    make = make_operator
    assert callable(make)
    operator = make()
    assert _sale(api, operator.headers, sale_payload).status_code == 400
    key = f"conflict-{uuid4()}"
    assert _sale(api, operator.headers, sale_payload, key).status_code == 201
    conflict = _sale(api, operator.headers, sale_payload | {"amount": "3"}, key)
    assert conflict.status_code == 409
    assert set(conflict.json()) == {"message"}


@pytest.mark.parametrize(
    ("reply", "expected_status"),
    [
        (
            {
                "body": {
                    "status": "DECLINED",
                    "response_code": "05",
                    "user_message": "No",
                }
            },
            "DECLINED",
        ),
        ({"status_code": 503, "body": {"message": "unavailable"}}, "FAILED"),
    ],
)
def test_sale_terminal_gateway_outcomes(
    api: httpx.Client,
    gateway: httpx.Client,
    make_operator: object,
    sale_payload: dict[str, str],
    reply: dict[str, object],
    expected_status: str,
) -> None:
    make = make_operator
    assert callable(make)
    # The seeded production policy performs up to three safe retries after a
    # NOT_SENT result. Supply all three so the stub never falls back to its
    # default approval response.
    set_gateway_scenario(gateway, "authorize", reply, reply, reply)
    response = _sale(api, make().headers, sale_payload, f"outcome-{uuid4()}")
    assert response.status_code == 201
    assert response.json()["status"] == expected_status
    if expected_status == "FAILED":
        assert len(gateway_requests(gateway, "authorize")) == 3


def test_ambiguous_sale_is_pending_and_never_reauthorizes_on_replay(
    api: httpx.Client,
    gateway: httpx.Client,
    make_operator: object,
    sale_payload: dict[str, str],
) -> None:
    ready = api.get("/health/ready")
    assert ready.status_code in (200, 503)
    if ready.json()["recovery_worker"]["enabled"]:
        pytest.skip("PENDING contract requires the recovery worker disabled")

    make = make_operator
    assert callable(make)
    set_gateway_scenario(gateway, "authorize", {"status_code": 502, "body": "bad"})
    operator = make()
    key = f"ambiguous-{uuid4()}"
    created = _sale(api, operator.headers, sale_payload, key)
    assert created.status_code == 202
    assert created.json()["status"] == "PENDING"
    assert created.json()["reason"] == "PROCESSING"
    assert created.json()["poll_after_seconds"] == 2
    assert created.json()["may_start_new_sale"] is False

    replay = _sale(api, operator.headers, sale_payload, key)
    assert replay.status_code == 202
    assert len(gateway_requests(gateway, "authorize")) == 1
    detail = api.get(
        f"/v1/transactions/{created.json()['transaction_number']}",
        headers=operator.headers,
    )
    assert detail.status_code == 202
    assert detail.headers["retry-after"] == "2"


def test_same_idempotency_key_is_safe_under_concurrent_requests(
    api: httpx.Client,
    gateway: httpx.Client,
    make_operator: object,
    sale_payload: dict[str, str],
) -> None:
    make = make_operator
    assert callable(make)
    set_gateway_scenario(
        gateway,
        "authorize",
        {
            "delay_seconds": 0.2,
            "body": {
                "status": "APPROVED",
                "response_code": "00",
                "user_message": "Pago aprobado",
            },
        },
    )
    operator = make()
    key = f"concurrent-{uuid4()}"
    with ThreadPoolExecutor(max_workers=2) as executor:
        responses = list(
            executor.map(
                lambda _: _sale(api, operator.headers, sale_payload, key), range(2)
            )
        )
    assert {response.status_code for response in responses} <= {200, 201, 202}
    assert len(gateway_requests(gateway, "authorize")) == 1


def test_detail_is_scoped_to_the_authenticated_terminal(
    api: httpx.Client, make_operator: object, sale_payload: dict[str, str]
) -> None:
    make = make_operator
    assert callable(make)
    owner = make()
    other = make()
    created = _sale(api, owner.headers, sale_payload, f"isolated-{uuid4()}").json()
    response = api.get(
        f"/v1/transactions/{created['transaction_number']}", headers=other.headers
    )
    assert response.status_code == 404


def test_void_approved_declined_and_card_mismatch(
    api: httpx.Client,
    gateway: httpx.Client,
    make_operator: object,
    sale_payload: dict[str, str],
) -> None:
    make = make_operator
    assert callable(make)
    operator = make()
    approved = _sale(api, operator.headers, sale_payload, f"void-sale-{uuid4()}").json()
    target = f"/v1/transactions/{approved['transaction_number']}/void"
    mismatch = api.post(
        target,
        headers=operator.headers | {"Idempotency-Key": f"void-{uuid4()}"},
        json={"card_number": "6063007014007401", "expiration_date": "2912"},
    )
    assert mismatch.status_code == 400

    set_gateway_scenario(
        gateway,
        "void",
        {"body": {"status": "DECLINED", "response_code": "05", "user_message": "No"}},
    )
    declined = api.post(
        target,
        headers=operator.headers | {"Idempotency-Key": f"void-{uuid4()}"},
        json={"card_number": sale_payload["card_number"], "expiration_date": "2912"},
    )
    assert declined.status_code == 200
    assert declined.json()["status"] == "APPROVED"

    voided = api.post(
        target,
        headers=operator.headers | {"Idempotency-Key": f"void-{uuid4()}"},
        json={"card_number": sale_payload["card_number"], "expiration_date": "2912"},
    )
    assert voided.status_code == 200
    assert voided.json()["status"] == "VOIDED"
    assert len(gateway_requests(gateway, "void")) == 2


def test_batch_close_isolated_idempotent_and_blocks_voids(
    api: httpx.Client, make_operator: object, sale_payload: dict[str, str]
) -> None:
    make = make_operator
    assert callable(make)
    operator = make()
    transaction = _sale(
        api, operator.headers, sale_payload, f"batch-sale-{uuid4()}"
    ).json()
    key = f"batch-{uuid4()}"
    closed = api.post(
        "/v1/transactions/batch-close",
        headers=operator.headers | {"Idempotency-Key": key},
    )
    assert closed.status_code == 201
    assert closed.json()["total"] == 1
    assert api.get("/v1/transactions", headers=operator.headers).json()["total"] == 0
    replay = api.post(
        "/v1/transactions/batch-close",
        headers=operator.headers | {"Idempotency-Key": key},
    )
    assert replay.status_code == 201
    assert replay.json()["batch_close_id"] == closed.json()["batch_close_id"]
    rejected_void = api.post(
        f"/v1/transactions/{transaction['transaction_number']}/void",
        headers=operator.headers | {"Idempotency-Key": f"void-{uuid4()}"},
        json={"card_number": sale_payload["card_number"]},
    )
    assert rejected_void.status_code == 400
    empty = api.post(
        "/v1/transactions/batch-close",
        headers=operator.headers | {"Idempotency-Key": f"empty-{uuid4()}"},
    )
    assert empty.status_code == 409


def test_balance_full_success_and_atomic_failure(
    api: httpx.Client, gateway: httpx.Client, make_operator: object
) -> None:
    make = make_operator
    assert callable(make)
    operator = make()
    payload = {"card_number": "6063007014007403", "expiration_date": "2912"}
    ok = api.post("/v1/balance", headers=operator.headers, json=payload)
    assert ok.status_code == 200
    assert ok.json()["status"] == "APPROVED"
    assert len(ok.json()["balances"]) == 5
    assert len(gateway_requests(gateway, "balance")) == 5

    set_gateway_scenario(gateway, "balance", {"status_code": 503, "body": {}})
    failed = api.post("/v1/balance", headers=operator.headers, json=payload)
    assert failed.status_code == 200
    assert failed.json()["status"] == "FAILED"
    assert failed.json()["balances"] == []
