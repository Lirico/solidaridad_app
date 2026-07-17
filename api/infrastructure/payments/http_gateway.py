"""HTTP client for payment-gateway authorize."""

import httpx

from application.payments.ports import (
    AuthorizeRequest,
    AuthorizeResult,
    GatewayOutcome,
)


class HttpPaymentGateway:
    def __init__(
        self,
        *,
        base_url: str,
        timeout_seconds: float,
        client: httpx.Client | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._owns_client = client is None
        self._client = client or httpx.Client(
            base_url=self._base_url,
            timeout=timeout_seconds,
        )

    def close(self) -> None:
        if self._owns_client:
            self._client.close()

    def authorize(self, request: AuthorizeRequest) -> AuthorizeResult:
        payload = {
            "product_code": request.product_code,
            "amount_minor": request.amount_minor,
            "card_number": request.card_number,
            "terminal_id": request.terminal_id,
            "stan": request.stan,
        }
        if request.expiration_date is not None:
            payload["expiration_date"] = request.expiration_date

        try:
            response = self._client.post("/v1/authorize", json=payload)
        except httpx.ConnectError:
            return AuthorizeResult(outcome=GatewayOutcome.FAILED)
        except httpx.TimeoutException:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)
        except httpx.HTTPError:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)

        if response.status_code == 502:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 500:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 400:
            # Validation / domain errors from gateway — treat as no impact
            # only if we never reached processor; gateway 400 means bad request.
            return AuthorizeResult(outcome=GatewayOutcome.FAILED)

        try:
            data = response.json()
        except ValueError:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)

        status = str(data.get("status", "")).upper()
        if status == "APPROVED":
            outcome = GatewayOutcome.APPROVED
        elif status == "DECLINED":
            outcome = GatewayOutcome.DECLINED
        elif status == "FAILED":
            # Gateway FAILED is often unparseable ISO after send → UNKNOWN
            outcome = GatewayOutcome.UNKNOWN
        else:
            outcome = GatewayOutcome.UNKNOWN

        return AuthorizeResult(
            outcome=outcome,
            response_code=data.get("response_code"),
            user_message=data.get("user_message"),
            auth_id=data.get("auth_id"),
            retrieval_reference=data.get("retrieval_reference"),
        )
