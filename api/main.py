from fastapi import APIRouter, FastAPI

from presentation import create_router


def create_app(router: APIRouter) -> FastAPI:
    app = FastAPI(title="Solidaridad API")
    app.include_router(router)
    return app


router = create_router()
app = create_app(router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
