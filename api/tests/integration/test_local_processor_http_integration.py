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
EXPIRATION_DATE = "1229"


def _sale(
    api: httpx.Client,
    operator: Operator,
    *,
    card_number: str,
) -> httpx.Response:
    return api.post(
        "/v1/transactions",
        headers={
            **operator.headers,
            "Idempotency-Key": f"processor-{uuid4()}",
        },
        json={
            "product": "GARRAFA_10",
            "amount": "1",
            "card_number": card_number,
            "expiration_date": EXPIRATION_DATE,
            "cvv": "111",
        },
    )


def _local_processor_operator(api: httpx.Client) -> Operator:
    unique = uuid4().hex
    password = "integration-password-123"
    response = api.post(
        "/v1/auth/register",
        json={
            "name": "Local Processor Integration Operator",
            "email": f"processor-integration-{unique}@example.com",
            "password": password,
            # This is the terminal configured by 03_fix_demo.sql.
            "installation_id": "05000001",
        },
    )
    assert response.status_code == 201, response.text
    return Operator(
        token=response.json()["token"],
        email=response.json()["email"],
        password=password,
        installation_id="05000001",
    )


def test_local_processor_approves_known_funded_card(api: httpx.Client) -> None:
    response = _sale(api, _local_processor_operator(api), card_number=APPROVED_CARD)

    assert response.status_code == 201, response.text
    assert response.json()["status"] == "APPROVED"


@pytest.mark.parametrize(
    "card_number",
    [INSUFFICIENT_FUNDS_CARD, NO_PRODUCT_CARD, UNKNOWN_CARD],
)
def test_local_processor_rejects_known_fixture_cards(
    api: httpx.Client,
    card_number: str,
) -> None:
    response = _sale(api, _local_processor_operator(api), card_number=card_number)

    assert response.status_code == 201, response.text
    assert response.json()["status"] == "DECLINED"


def test_local_processor_balance_exposes_fixture_balance(api: httpx.Client) -> None:
    response = api.post(
        "/v1/balance",
        headers=_local_processor_operator(api).headers,
        json={"card_number": BALANCE_CARD, "expiration_date": EXPIRATION_DATE},
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["status"] == "APPROVED"
    approved_product = next(
        item for item in payload["balances"] if item["product"] == "GARRAFA_10"
    )
    assert approved_product["available_balance"] == "100"
