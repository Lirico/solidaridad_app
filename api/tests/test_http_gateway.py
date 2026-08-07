import httpx

from application.payments.ports import AuthorizeRequest, GatewayOutcome
from infrastructure.payments.http_gateway import HttpPaymentGateway


def _request() -> AuthorizeRequest:
    return AuthorizeRequest(
        product_code="993",
        amount_minor=150,
        card_number="4111111111111111",
        terminal_id="05000001",
        stan="000001",
        transaction_number="OP-260716-0001",
        expiration_date="2912",
    )



def _gateway(handler: object) -> HttpPaymentGateway:
    transport = httpx.MockTransport(handler)  # type: ignore[arg-type]
    client = httpx.Client(transport=transport, base_url="http://gw")
    return HttpPaymentGateway(base_url="http://gw", timeout_seconds=5, client=client)


def test_authorize_approved() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
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
    assert result.outcome == GatewayOutcome.APPROVED
    assert result.response_code == "00"


def test_authorize_declined() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"status": "DECLINED", "response_code": "51", "user_message": "x"},
        )

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.DECLINED


def test_authorize_failed_status_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"status": "FAILED", "response_code": "96", "user_message": "x"},
        )

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_authorize_unknown_status() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"status": "WTF"})

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_authorize_connect_error_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom", request=request)

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.FAILED


def test_authorize_timeout_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timeout", request=request)

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_authorize_http_error_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.RemoteProtocolError("x", request=request)

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_authorize_502_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(502, json={"message": "down"})

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_authorize_500_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"message": "err"})

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_authorize_400_is_failed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(400, json={"message": "bad"})

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.FAILED


def test_authorize_invalid_json_is_unknown() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not-json")

    assert _gateway(handler).authorize(_request()).outcome == GatewayOutcome.UNKNOWN


def test_close_owned_client() -> None:
    gateway = HttpPaymentGateway(base_url="http://gw", timeout_seconds=1)
    gateway.close()
