"""E2E checks against payment-gateway TCP and the local C processor.

This module is separate from the controlled-gateway suite: a legacy processor
cannot deterministically manufacture connection failures or delayed replies.
The root ``make integ-test-processor`` resets its local MySQL volume and
installs these card fixtures before collecting this module.
"""

import os
from uuid import uuid4

import httpx
import pytest

from tests.integration.conftest import Operator

pytestmark = pytest.mark.skipif(
    os.environ.get("INTEGRATION_PROCESSOR_TESTS") != "1",
    reason="requires the local processor fixture stack",
)

APPROVED_CARD = "6063007014990001"
INSUFFICIENT_FUNDS_CARD = "6063007014990002"
NO_PRODUCT_CARD = "6063007014990003"
UNKNOWN_CARD = "6063007014990099"
BALANCE_CARD = "6063007014990004"
IDEMPOTENCY_CARD = "6063007014990005"
VOID_CARD = "6063007014990006"
BATCH_CLOSE_CARD = "6063007014990007"
EXPIRATION_DATE = "1229"


def _sale(
    api: httpx.Client,
    operator: Operator,
    *,
    card_number: str,
    idempotency_key: str | None = None,
) -> httpx.Response:
    return api.post(
        "/v1/transactions",
        headers={
            **operator.headers,
            "Idempotency-Key": idempotency_key or f"processor-{uuid4()}",
        },
        json={
            "product": "GARRAFA_10",
            "amount": "1",
            "card_number": card_number,
            "expiration_date": EXPIRATION_DATE,
            "cvv": "111",
        },
    )


@pytest.fixture
def local_processor_operator(make_operator: object) -> Operator:
    assert callable(make_operator)
    return make_operator(installation_id="05000001", merchant_code="012502")


def test_real_stack_authentication_merchant_and_catalog(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    assert api.get("/ping").json() == {"status": "ok"}
    assert api.get("/health/live").status_code == 200
    assert api.get("/v1/me/merchant").status_code == 401
    assert api.get("/v1/products").status_code == 401

    login = api.post(
        "/v1/auth/login",
        json={
            "username": local_processor_operator.email,
            "password": local_processor_operator.password,
            "installation_id": local_processor_operator.installation_id,
        },
    )
    assert login.status_code == 200, login.text
    assert login.json()["merchant"]["code"] == "012502"

    invalid_login = api.post(
        "/v1/auth/login",
        json={
            "username": local_processor_operator.email,
            "password": "not-the-password",
            "installation_id": local_processor_operator.installation_id,
        },
    )
    assert invalid_login.status_code == 401

    merchant = api.get("/v1/me/merchant", headers=local_processor_operator.headers)
    assert merchant.status_code == 200, merchant.text
    assert merchant.json()["merchant"] == {
        "code": "012502",
        "name": "COMERCIO DEMO",
        "address": "DOMICILIO DEMO",
        "city": "LOCALIDAD DEMO",
        "tax_id": "CUIT DEMO",
    }

    products = api.get("/v1/products", headers=local_processor_operator.headers)
    assert products.status_code == 200, products.text
    assert [product["code"] for product in products.json()] == [
        "GARRAFA_10",
        "GARRAFA_15",
        "GARRAFA_30",
        "TUBO_45",
        "GRANEL",
    ]


def test_real_stack_change_password(
    local_processor_operator: Operator, api: httpx.Client
) -> None:
    new_password = "changed-integration-password-123"
    changed = api.post(
        "/v1/auth/change-password",
        headers=local_processor_operator.headers,
        json={
            "current_password": local_processor_operator.password,
            "new_password": new_password,
        },
    )
    assert changed.status_code == 200, changed.text

    old_login = api.post(
        "/v1/auth/login",
        json={
            "username": local_processor_operator.email,
            "password": local_processor_operator.password,
            "installation_id": local_processor_operator.installation_id,
        },
    )
    assert old_login.status_code == 401

    new_login = api.post(
        "/v1/auth/login",
        json={
            "username": local_processor_operator.email,
            "password": new_password,
            "installation_id": local_processor_operator.installation_id,
        },
    )
    assert new_login.status_code == 200, new_login.text


def test_local_processor_approves_known_funded_card(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    response = _sale(api, local_processor_operator, card_number=APPROVED_CARD)

    assert response.status_code == 201, response.text
    assert response.json()["status"] == "APPROVED"


def test_real_stack_rejects_invalid_requests_before_processor(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    payload = {
        "product": "GARRAFA_10",
        "amount": "1",
        "card_number": APPROVED_CARD,
        "expiration_date": EXPIRATION_DATE,
    }
    missing_key = api.post(
        "/v1/transactions", headers=local_processor_operator.headers, json=payload
    )
    assert missing_key.status_code == 400
    assert missing_key.json() == {"message": "Idempotency-Key es requerido"}

    invalid_card = api.post(
        "/v1/transactions",
        headers=local_processor_operator.headers | {"Idempotency-Key": str(uuid4())},
        json=payload | {"card_number": "123"},
    )
    assert invalid_card.status_code == 400

    invalid_balance = api.post(
        "/v1/balance",
        headers=local_processor_operator.headers,
        json={"card_number": "123", "expiration_date": EXPIRATION_DATE},
    )
    assert invalid_balance.status_code == 400

    missing_transaction = api.get(
        "/v1/transactions/OP-000000-00000000",
        headers=local_processor_operator.headers,
    )
    assert missing_transaction.status_code == 404


def test_real_stack_idempotency_lookup_and_listing(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    key = f"processor-idempotency-{uuid4()}"
    created = _sale(
        api,
        local_processor_operator,
        card_number=IDEMPOTENCY_CARD,
        idempotency_key=key,
    )
    replay = _sale(
        api,
        local_processor_operator,
        card_number=IDEMPOTENCY_CARD,
        idempotency_key=key,
    )

    assert created.status_code == 201, created.text
    assert replay.status_code == 200, replay.text
    assert replay.json()["transaction_number"] == created.json()["transaction_number"]
    assert replay.json()["status"] == "APPROVED"

    transaction_number = created.json()["transaction_number"]
    lookup = api.get(
        f"/v1/transactions/{transaction_number}",
        headers=local_processor_operator.headers,
    )
    assert lookup.status_code == 200, lookup.text
    assert lookup.json()["status"] == "APPROVED"

    listing = api.get("/v1/transactions", headers=local_processor_operator.headers)
    assert listing.status_code == 200, listing.text
    assert any(
        item["transaction_number"] == transaction_number
        for item in listing.json()["items"]
    )


def test_real_stack_approves_void_for_known_card(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    created = _sale(api, local_processor_operator, card_number=VOID_CARD)
    assert created.status_code == 201, created.text
    transaction_number = created.json()["transaction_number"]

    voided = api.post(
        f"/v1/transactions/{transaction_number}/void",
        headers=local_processor_operator.headers | {
            "Idempotency-Key": f"processor-void-{uuid4()}"
        },
        json={"card_number": VOID_CARD, "expiration_date": EXPIRATION_DATE},
    )
    assert voided.status_code == 200, voided.text
    assert voided.json()["status"] == "VOIDED"

    status = api.get(
        f"/v1/transactions/{transaction_number}/void",
        headers=local_processor_operator.headers,
    )
    assert status.status_code == 200, status.text
    assert status.json()["status"] == "VOIDED"


def test_real_stack_closes_current_batch(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    created = _sale(api, local_processor_operator, card_number=BATCH_CLOSE_CARD)
    assert created.status_code == 201, created.text
    transaction_number = created.json()["transaction_number"]

    missing_key = api.post(
        "/v1/transactions/batch-close", headers=local_processor_operator.headers
    )
    assert missing_key.status_code == 400

    key = f"processor-batch-{uuid4()}"
    closed = api.post(
        "/v1/transactions/batch-close",
        headers=local_processor_operator.headers | {"Idempotency-Key": key},
    )
    assert closed.status_code == 201, closed.text
    assert any(
        item["transaction_number"] == transaction_number
        for item in closed.json()["items"]
    )

    replay = api.post(
        "/v1/transactions/batch-close",
        headers=local_processor_operator.headers | {"Idempotency-Key": key},
    )
    assert replay.status_code == 201, replay.text
    assert replay.json()["batch_close_id"] == closed.json()["batch_close_id"]

    listing = api.get("/v1/transactions", headers=local_processor_operator.headers)
    assert listing.status_code == 200, listing.text
    assert listing.json()["total"] == 0


@pytest.mark.parametrize(
    "card_number",
    [INSUFFICIENT_FUNDS_CARD, NO_PRODUCT_CARD, UNKNOWN_CARD],
)
def test_local_processor_rejects_known_fixture_cards(
    api: httpx.Client,
    card_number: str,
    local_processor_operator: Operator,
) -> None:
    response = _sale(api, local_processor_operator, card_number=card_number)

    assert response.status_code == 201, response.text
    assert response.json()["status"] == "DECLINED"


def test_local_processor_balance_exposes_fixture_balance(
    api: httpx.Client, local_processor_operator: Operator
) -> None:
    response = api.post(
        "/v1/balance",
        headers=local_processor_operator.headers,
        json={"card_number": BALANCE_CARD, "expiration_date": EXPIRATION_DATE},
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["status"] == "APPROVED"
    approved_product = next(
        item for item in payload["balances"] if item["product"] == "GARRAFA_10"
    )
    assert approved_product["available_balance"] == "100"
