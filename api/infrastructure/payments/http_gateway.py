"""HTTP client for payment-gateway payment operations."""

import httpx

from application.payments.ports import (
    AuthorizationGatewayOutcome,
    AuthorizeRequest,
    AuthorizeResult,
    BalanceRequest,
    BalanceResult,
    GatewayOutcome,
    ReversalOutcome,
    ReverseRequest,
    ReverseResult,
    VoidRequest,
    VoidResult,
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
        }
        if request.expiration_date is not None:
            payload["expiration_date"] = request.expiration_date
        return self._post_authorize("/v1/authorize", payload)

    def void(self, request: VoidRequest) -> VoidResult:
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
        return self._post_legacy("/v1/void", payload)

    def balance(self, request: BalanceRequest) -> BalanceResult:
        payload: dict[str, object] = {
            "product_code": request.product_code,
            "card_number": request.card_number,
            "terminal_id": request.terminal_id,
            "stan": request.stan,
        }
        if request.expiration_date is not None:
            payload["expiration_date"] = request.expiration_date
        return self._post_balance("/v1/balance", payload)

    def reverse(self, request: ReverseRequest) -> ReverseResult:
        payload = {
            "product_code": request.product_code,
            "amount_minor": request.amount_minor,
            "card_number": request.card_number,
            "expiration_date": request.expiration_date,
            "terminal_id": request.terminal_id,
            "original_stan": request.original_stan,
            "original_ticket": request.original_ticket,
            "reversal_stan": request.reversal_stan,
        }
        try:
            response = self._client.post("/v1/reverse", json=payload)
        except httpx.ConnectError:
            return ReverseResult(outcome=ReversalOutcome.NOT_SENT)
        except (httpx.TimeoutException, httpx.HTTPError):
            return ReverseResult(outcome=ReversalOutcome.INDETERMINATE)

        if response.status_code == 503:
            return ReverseResult(outcome=ReversalOutcome.NOT_SENT)
        if response.status_code >= 500:
            return ReverseResult(outcome=ReversalOutcome.INDETERMINATE)
        if response.status_code >= 400:
            return ReverseResult(outcome=ReversalOutcome.NOT_SENT)

        data = self._json_object(response)
        if data is None:
            return ReverseResult(outcome=ReversalOutcome.INDETERMINATE)
        try:
            outcome = ReversalOutcome(str(data.get("status", "")).upper())
        except (TypeError, ValueError):
            outcome = ReversalOutcome.INDETERMINATE
        response_code = self._optional_str(data.get("response_code"))
        user_message = self._optional_str(data.get("user_message"))
        if response_code is None or user_message is None:
            return ReverseResult(outcome=ReversalOutcome.INDETERMINATE)
        return ReverseResult(
            outcome=outcome,
            response_code=response_code,
            user_message=user_message,
        )

    def _post_authorize(
        self,
        path: str,
        payload: dict[str, object],
    ) -> AuthorizeResult:
        try:
            response = self._client.post(path, json=payload)
        except httpx.ConnectError:
            return AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT)
        except (httpx.TimeoutException, httpx.HTTPError):
            return AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.INDETERMINATE
            )

        # 503 = el gateway no llegó a conectar con el procesador: el mensaje ISO
        # nunca salió, así que no hay impacto posible. 502 sí es ambiguo.
        if response.status_code == 503:
            return AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT)
        if response.status_code >= 500:
            return AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.INDETERMINATE
            )
        if response.status_code >= 400:
            return AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT)

        data = self._json_object(response)
        if data is None:
            return AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.INDETERMINATE
            )

        status = str(data.get("status", "")).upper()
        if status == "APPROVED":
            outcome = AuthorizationGatewayOutcome.APPROVED
        elif status == "DECLINED":
            outcome = AuthorizationGatewayOutcome.DECLINED
        else:
            outcome = AuthorizationGatewayOutcome.INDETERMINATE

        response_code = self._optional_str(data.get("response_code"))
        user_message = self._optional_str(data.get("user_message"))
        if response_code is None or user_message is None:
            return AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.INDETERMINATE
            )
        return AuthorizeResult(
            outcome=outcome,
            response_code=response_code,
            user_message=user_message,
            auth_id=self._optional_str(data.get("auth_id")),
            retrieval_reference=self._optional_str(
                data.get("retrieval_reference")
            ),
        )

    def _post_legacy(
        self,
        path: str,
        payload: dict[str, object],
    ) -> VoidResult:
        try:
            response = self._client.post(path, json=payload)
        except httpx.ConnectError:
            return VoidResult(outcome=GatewayOutcome.FAILED)
        except (httpx.TimeoutException, httpx.HTTPError):
            return VoidResult(outcome=GatewayOutcome.UNKNOWN)

        if response.status_code == 503:
            return VoidResult(outcome=GatewayOutcome.FAILED)
        if response.status_code >= 500:
            return VoidResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 400:
            return VoidResult(outcome=GatewayOutcome.FAILED)

        data = self._json_object(response)
        if data is None:
            return VoidResult(outcome=GatewayOutcome.UNKNOWN)
        status = str(data.get("status", "")).upper()
        outcome = {
            "APPROVED": GatewayOutcome.APPROVED,
            "DECLINED": GatewayOutcome.DECLINED,
        }.get(status, GatewayOutcome.UNKNOWN)
        return VoidResult(
            outcome=outcome,
            response_code=self._optional_str(data.get("response_code")),
            user_message=self._optional_str(data.get("user_message")),
            auth_id=self._optional_str(data.get("auth_id")),
            retrieval_reference=self._optional_str(
                data.get("retrieval_reference")
            ),
        )

    @staticmethod
    def _json_object(response: httpx.Response) -> dict[str, object] | None:
        try:
            data = response.json()
        except ValueError:
            return None
        return data if isinstance(data, dict) else None

    @staticmethod
    def _optional_str(value: object) -> str | None:
        return value if isinstance(value, str) else None

    def _post_balance(
        self,
        path: str,
        payload: dict[str, object],
    ) -> BalanceResult:
        try:
            response = self._client.post(path, json=payload)
        except httpx.ConnectError:
            return BalanceResult(outcome=GatewayOutcome.FAILED)
        except httpx.TimeoutException:
            return BalanceResult(outcome=GatewayOutcome.UNKNOWN)
        except httpx.HTTPError:
            return BalanceResult(outcome=GatewayOutcome.UNKNOWN)

        if response.status_code == 503:
            return BalanceResult(outcome=GatewayOutcome.FAILED)
        if response.status_code == 502:
            return BalanceResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 500:
            return BalanceResult(outcome=GatewayOutcome.UNKNOWN)
        if response.status_code >= 400:
            return BalanceResult(outcome=GatewayOutcome.FAILED)

        try:
            data = response.json()
        except ValueError:
            return BalanceResult(outcome=GatewayOutcome.UNKNOWN)

        status = str(data.get("status", "")).upper()
        if status == "APPROVED":
            outcome = GatewayOutcome.APPROVED
        elif status == "DECLINED":
            outcome = GatewayOutcome.DECLINED
        elif status == "FAILED":
            outcome = GatewayOutcome.FAILED
        else:
            outcome = GatewayOutcome.UNKNOWN

        return BalanceResult(
            outcome=outcome,
            response_code=data.get("response_code"),
            user_message=data.get("user_message"),
            available_balance_minor=data.get("available_balance_minor"),
            assigned_products=data.get("assigned_products"),
        )
