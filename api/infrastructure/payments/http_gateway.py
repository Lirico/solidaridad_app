"""HTTP client for payment-gateway authorize / void."""

import httpx

from application.payments.ports import (
    AuthorizeRequest,
    AuthorizeResult,
    GatewayOutcome,
    VoidRequest,
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
            "ticket_number": request.ticket_number,
            "entry_mode": request.entry_mode,
        }
        if request.expiration_date is not None:
            payload["expiration_date"] = request.expiration_date
        if request.track2 is not None:
            payload["track2"] = request.track2
        if request.cvv is not None:
            payload["cvv"] = request.cvv
        return self._post("/v1/authorize", payload)

    def void(self, request: VoidRequest) -> AuthorizeResult:
        payload = {
            "product_code": request.product_code,
            "amount_minor": request.amount_minor,
            "card_number": request.card_number,
            "terminal_id": request.terminal_id,
            "stan": request.stan,
            "original_ticket": request.original_ticket,
            "void_ticket": request.void_ticket,
        }
        if request.expiration_date is not None:
            payload["expiration_date"] = request.expiration_date
        return self._post("/v1/void", payload)

    def _post(self, path: str, payload: dict[str, object]) -> AuthorizeResult:
        try:
            response = self._client.post(path, json=payload)
        except httpx.ConnectError:
            return AuthorizeResult(outcome=GatewayOutcome.FAILED)
        except httpx.TimeoutException:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)
        except httpx.HTTPError:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)

        # 503 = el gateway no llegó a conectar con el procesador: el mensaje ISO
        # nunca salió, así que no hay impacto posible. 502 sí es ambiguo.
        if response.status_code == 503:
            return AuthorizeResult(outcome=GatewayOutcome.FAILED)
        if response.status_code == 502:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 500:
            return AuthorizeResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 400:
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
