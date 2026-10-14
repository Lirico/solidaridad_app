import json

import httpx
import pytest

from application.payments.ports import (
    AuthorizationGatewayOutcome,
    AuthorizeRequest,
    BalanceRequest,
    GatewayOutcome,
    ReversalOutcome,
    ReverseRequest,
)
from infrastructure.payments.http_gateway import HttpPaymentGateway


def _request() -> AuthorizeRequest:
    return AuthorizeRequest(
        product_code="993",
        amount_minor=150,
        card_number="4111111111111111",
        terminal_id="05000001",
        stan="000001",
        ticket_number="00000001",
        idempotency_key="payment-key-1",
        expiration_date="2912",
    )


def _gateway(handler: object) -> HttpPaymentGateway:
    transport = httpx.MockTransport(handler)  # type: ignore[arg-type]
    client = httpx.Client(transport=transport, base_url="http://gw")
    return HttpPaymentGateway(base_url="http://gw", timeout_seconds=5, client=client)


def test_authorize_approved() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Idempotency-Key"] == "payment-key-1"
        return httpx.Response(
            200,
            json={
                "status": "APPROVED",
                "response_code": "00",
                "user_message": "Aprobada",
                "auth_id": "A1",
                "retrieval_reference": "R1",
            },
        )

    result = _gateway(handler).authorize(_request())
    assert result.outcome == AuthorizationGatewayOutcome.APPROVED
    assert result.response_code == "00"


def test_authorize_declined() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"status": "DECLINED", "response_code": "51", "user_message": "x"},
        )

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.DECLINED
    )


def test_authorize_failed_status_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"status": "FAILED", "response_code": "96", "user_message": "x"},
        )

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_unknown_status() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"status": "WTF"})

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_connect_error_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom", request=request)

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.NOT_SENT
    )


def test_authorize_timeout_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timeout", request=request)

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_connect_timeout_is_indeterminate() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timeout", request=request)

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_http_error_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.RemoteProtocolError("x", request=request)

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_502_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(502, json={"message": "down"})

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_503_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"message": "processor unreachable"})

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.NOT_SENT
    )


def test_authorize_500_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"message": "err"})

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_400_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(400, json={"message": "bad"})

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.NOT_SENT
    )


def test_authorize_invalid_json_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not-json")

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_non_object_json_is_indeterminate() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=["APPROVED"])

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def test_authorize_missing_required_response_field_is_indeterminate() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"status": "APPROVED", "response_code": "00"})

    assert (
        _gateway(handler).authorize(_request()).outcome
        == AuthorizationGatewayOutcome.INDETERMINATE
    )


def _reverse_request() -> ReverseRequest:
    return ReverseRequest(
        product_code="993",
        amount_minor=150,
        card_number="4111111111111111",
        expiration_date="2912",
        terminal_id="05000001",
        original_stan="000001",
        original_ticket="00000001",
        reversal_stan="000002",
    )


def test_reverse_posts_exact_payload_and_maps_confirmed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/reverse"
        assert json.loads(request.content) == {
            "product_code": "993",
            "amount_minor": 150,
            "card_number": "4111111111111111",
            "expiration_date": "2912",
            "terminal_id": "05000001",
            "original_stan": "000001",
            "original_ticket": "00000001",
            "reversal_stan": "000002",
        }
        return httpx.Response(
            200,
            json={
                "status": "REVERSED_CONFIRMED",
                "response_code": "00",
                "user_message": "Reverso aceptado",
            },
        )

    result = _gateway(handler).reverse(_reverse_request())

    assert result.outcome == ReversalOutcome.REVERSED_CONFIRMED
    assert result.response_code == "00"


@pytest.mark.parametrize(
    ("status", "expected"),
    [
        ("PROCESSOR_DECLINED", ReversalOutcome.PROCESSOR_DECLINED),
        ("NOT_SENT", ReversalOutcome.NOT_SENT),
        ("INDETERMINATE", ReversalOutcome.INDETERMINATE),
    ],
)
def test_reverse_maps_gateway_statuses(
    status: str,
    expected: ReversalOutcome,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "status": status,
                "response_code": "96",
                "user_message": "Resultado del reverso",
            },
        )

    assert _gateway(handler).reverse(_reverse_request()).outcome == expected


def test_reverse_connect_error_is_not_sent() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    assert (
        _gateway(handler).reverse(_reverse_request()).outcome
        == ReversalOutcome.NOT_SENT
    )


@pytest.mark.parametrize(
    "error_type",
    [httpx.ConnectTimeout, httpx.ReadTimeout, httpx.WriteTimeout],
)
def test_reverse_timeout_is_indeterminate(
    error_type: type[httpx.TimeoutException],
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise error_type("timeout", request=request)

    assert (
        _gateway(handler).reverse(_reverse_request()).outcome
        == ReversalOutcome.INDETERMINATE
    )


def test_reverse_disconnect_after_send_is_indeterminate() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.RemoteProtocolError("disconnected", request=request)

    assert (
        _gateway(handler).reverse(_reverse_request()).outcome
        == ReversalOutcome.INDETERMINATE
    )


@pytest.mark.parametrize(
    ("status_code", "expected"),
    [
        (400, ReversalOutcome.NOT_SENT),
        (502, ReversalOutcome.INDETERMINATE),
        (503, ReversalOutcome.NOT_SENT),
        (500, ReversalOutcome.INDETERMINATE),
    ],
)
def test_reverse_classifies_http_status(
    status_code: int,
    expected: ReversalOutcome,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code, json={"message": "gateway error"})

    assert _gateway(handler).reverse(_reverse_request()).outcome == expected


@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(200, content=b"invalid-json"),
        httpx.Response(200, json=[]),
        httpx.Response(200, json={"status": "UNRECOGNIZED"}),
        httpx.Response(
            200,
            json={"status": "REVERSED_CONFIRMED", "response_code": "00"},
        ),
    ],
)
def test_reverse_invalid_response_is_indeterminate(
    response: httpx.Response,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return response

    assert (
        _gateway(handler).reverse(_reverse_request()).outcome
        == ReversalOutcome.INDETERMINATE
    )


def test_payment_requests_hide_card_number_from_repr() -> None:
    assert "4111111111111111" not in repr(_request())
    assert "4111111111111111" not in repr(_reverse_request())


def test_close_owned_client() -> None:
    gateway = HttpPaymentGateway(base_url="http://gw", timeout_seconds=1)
    gateway.close()


def test_void_approved() -> None:
    from application.payments.ports import VoidRequest

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/void"
        return httpx.Response(
            200,
            json={
                "status": "APPROVED",
                "response_code": "00",
                "user_message": "Aprobada",
                "auth_id": "V1",
                "retrieval_reference": "R2",
            },
        )

    result = _gateway(handler).void(
        VoidRequest(
            product_code="993",
            amount_minor=150,
            card_number="4111111111111111",
            terminal_id="05000001",
            stan="000002",
            original_ticket="00000001",
            void_ticket="000002",
        )
    )
    assert result.outcome == GatewayOutcome.APPROVED
    assert result.auth_id == "V1"


def _balance_request() -> BalanceRequest:
    return BalanceRequest(
        product_code="993",
        card_number="4111111111111111",
        terminal_id="05000001",
        stan="000003",
        expiration_date="2912",
    )


def test_balance_approved() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/balance"
        return httpx.Response(
            200,
            json={
                "status": "APPROVED",
                "response_code": "00",
                "user_message": "Aprobada",
                "available_balance_minor": 10000,
                "assigned_products": "Tipo de asignacion: Garrafa 10 kg",
            },
        )

    result = _gateway(handler).balance(_balance_request())
    assert result.outcome == GatewayOutcome.APPROVED
    assert result.available_balance_minor == 10000
    assert result.assigned_products == "Tipo de asignacion: Garrafa 10 kg"


def test_balance_declined() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"status": "DECLINED", "response_code": "06", "user_message": "x"},
        )

    assert (
        _gateway(handler).balance(_balance_request()).outcome
        == GatewayOutcome.DECLINED
    )


def test_balance_connect_error_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom", request=request)

    assert (
        _gateway(handler).balance(_balance_request()).outcome
        == GatewayOutcome.FAILED
    )


def test_balance_503_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"message": "down"})

    assert (
        _gateway(handler).balance(_balance_request()).outcome
        == GatewayOutcome.FAILED
    )


def test_balance_502_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(502, json={"message": "ambiguous"})

    assert (
        _gateway(handler).balance(_balance_request()).outcome
        == GatewayOutcome.UNKNOWN
    )
