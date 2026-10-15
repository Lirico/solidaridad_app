import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Protocol

from fastapi import APIRouter, FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from application.payments.embedded_recovery_iteration import (
    create_embedded_recovery_iteration,
)
from application.payments.embedded_recovery_worker import (
    EmbeddedRecoveryWorker,
    RecoveryWorkerHealth,
)
from config import Settings, get_settings
from presentation import create_router

logger = logging.getLogger(__name__)


class ManagedRecoveryWorker(Protocol):
    def start(self) -> None: ...

    def stop(self, *, grace_seconds: float) -> bool: ...

    def health(self) -> RecoveryWorkerHealth: ...


def _validation_message(exc: RequestValidationError) -> str:
    errors = exc.errors()
    if not errors:
        return "Datos de entrada inválidos"
    first = errors[0]
    loc = first.get("loc", ())
    field = next(
        (str(part) for part in reversed(loc) if part not in {"body", "query", "path"}),
        None,
    )
    msg = str(first.get("msg", "Datos de entrada inválidos"))
    if field:
        return f"{field}: {msg}"
    return msg


def _http_exception_message(exc: HTTPException) -> str:
    detail = exc.detail
    if isinstance(detail, str):
        return detail
    if isinstance(detail, dict) and "message" in detail:
        return str(detail["message"])
    return str(detail)


def create_app(
    router: APIRouter,
    *,
    settings: Settings | None = None,
    recovery_worker: ManagedRecoveryWorker | None = None,
) -> FastAPI:
    runtime_settings = settings or get_settings()
    worker = recovery_worker or EmbeddedRecoveryWorker(
        run_iteration=create_embedded_recovery_iteration(settings=runtime_settings),
        enabled=runtime_settings.embedded_recovery_worker_enabled,
    )

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        if runtime_settings.embedded_recovery_worker_enabled:
            worker.start()
        try:
            yield
        finally:
            if runtime_settings.embedded_recovery_worker_enabled:
                stopped = worker.stop(
                    grace_seconds=(
                        runtime_settings.embedded_recovery_worker_shutdown_grace_seconds
                    )
                )
                if not stopped:
                    logger.error("embedded_recovery_worker_did_not_stop")

    app = FastAPI(title="Solidaridad API", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(router)

    @app.get("/health/live")
    def liveness() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def readiness() -> JSONResponse:
        health = worker.health()
        body = {
            "status": "ok" if health.ready else "degraded",
            "recovery_worker": {
                "enabled": health.enabled,
                "alive": health.alive,
                "stopping": health.stopping,
                "started_at": _timestamp(health.started_at),
                "last_iteration_at": _timestamp(health.last_iteration_at),
                "last_error": health.last_error,
            },
        }
        return JSONResponse(
            status_code=(
                status.HTTP_200_OK
                if health.ready
                else status.HTTP_503_SERVICE_UNAVAILABLE
            ),
            content=body,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        _request: Request,
        exc: RequestValidationError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": _validation_message(exc)},
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(
        _request: Request,
        exc: HTTPException,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"message": _http_exception_message(exc)},
            headers=exc.headers,
        )

    return app


def _timestamp(value: object) -> str | None:
    return value.isoformat() if hasattr(value, "isoformat") else None


router = create_router()
app = create_app(router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
