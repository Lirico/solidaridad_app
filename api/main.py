from fastapi import APIRouter, FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from presentation import create_router


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


def create_app(router: APIRouter) -> FastAPI:
    app = FastAPI(title="Solidaridad API")
    app.include_router(router)

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        _request: Request,
        exc: RequestValidationError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": _validation_message(exc)},
        )

    return app


router = create_router()
app = create_app(router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
