from fastapi import APIRouter

from presentation.controllers import auth_router, ping_router, transactions_router


def create_router() -> APIRouter:
    router = APIRouter()
    router.include_router(ping_router)

    v1 = APIRouter(prefix="/v1")
    v1.include_router(auth_router, prefix="/auth", tags=["auth"])
    v1.include_router(
        transactions_router,
        prefix="/transactions",
        tags=["transactions"],
    )
    router.include_router(v1)
    return router
