"""Scenario-driven HTTP gateway used only by the API integration environment.

It deliberately exposes its control API on a different port/process from the
API under test. Payment requests therefore exercise the real HTTP adapter in
``infrastructure.payments.http_gateway`` rather than an in-process mock.
"""

import time
from collections import defaultdict
from dataclasses import dataclass
from threading import Lock
from typing import Any

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response


@dataclass(frozen=True, slots=True)
class StubReply:
    status_code: int
    body: object
    delay_seconds: float
    content_type: str


class GatewayState:
    def __init__(self) -> None:
        self._lock = Lock()
        self.reset()

    def reset(self) -> None:
        with self._lock:
            self._replies: dict[str, list[StubReply]] = defaultdict(list)
            self._requests: list[dict[str, object]] = []

    def set_replies(self, route: str, replies: list[StubReply]) -> None:
        with self._lock:
            self._replies[route] = replies.copy()

    def take_reply(self, route: str, request: dict[str, object]) -> StubReply:
        with self._lock:
            self._requests.append({"route": route, **request})
            replies = self._replies[route]
            if replies:
                return replies.pop(0)
        return _default_reply(route)

    def requests(self) -> list[dict[str, object]]:
        with self._lock:
            return self._requests.copy()


def _default_reply(route: str) -> StubReply:
    if route == "balance":
        body: object = {
            "status": "APPROVED",
            "response_code": "00",
            "user_message": "Consulta de saldo exitosa",
            "available_balance_minor": 100,
        }
    elif route == "reverse":
        body = {
            "status": "REVERSED_CONFIRMED",
            "response_code": "00",
            "user_message": "Reverso confirmado",
        }
    else:
        body = {
            "status": "APPROVED",
            "response_code": "00",
            "user_message": "Pago aprobado",
        }
    return StubReply(200, body, 0, "application/json")


state = GatewayState()
app = FastAPI(title="Solidaridad integration gateway stub")


def _reply(reply: StubReply) -> Response:
    if reply.delay_seconds:
        time.sleep(reply.delay_seconds)
    if reply.content_type == "application/json":
        return JSONResponse(status_code=reply.status_code, content=reply.body)
    return Response(
        status_code=reply.status_code,
        content=str(reply.body),
        media_type=reply.content_type,
    )


async def _payment_request(request: Request, route: str) -> Response:
    try:
        payload = await request.json()
    except ValueError:
        payload = None
    return _reply(
        state.take_reply(
            route,
            {
                "body": payload,
                "idempotency_key": request.headers.get("Idempotency-Key"),
            },
        )
    )


@app.post("/v1/authorize")
async def authorize(request: Request) -> Response:
    return await _payment_request(request, "authorize")


@app.post("/v1/void")
async def void(request: Request) -> Response:
    return await _payment_request(request, "void")


@app.post("/v1/balance")
async def balance(request: Request) -> Response:
    return await _payment_request(request, "balance")


@app.post("/v1/reverse")
async def reverse(request: Request) -> Response:
    return await _payment_request(request, "reverse")


@app.post("/__test__/reset")
def reset() -> dict[str, str]:
    state.reset()
    return {"status": "ok"}


@app.post("/__test__/scenario")
async def scenario(request: Request) -> dict[str, object]:
    raw: dict[str, Any] = await request.json()
    route = raw.get("route")
    raw_replies = raw.get("replies")
    if route not in {"authorize", "void", "balance", "reverse"}:
        return {"message": "unknown route"}
    if not isinstance(raw_replies, list):
        return {"message": "replies must be a list"}
    replies = [
        StubReply(
            status_code=int(item.get("status_code", 200)),
            body=item.get("body", {}),
            delay_seconds=float(item.get("delay_seconds", 0)),
            content_type=str(item.get("content_type", "application/json")),
        )
        for item in raw_replies
        if isinstance(item, dict)
    ]
    state.set_replies(str(route), replies)
    return {"route": route, "count": len(replies)}


@app.get("/__test__/requests")
def requests() -> dict[str, object]:
    return {"items": state.requests()}
