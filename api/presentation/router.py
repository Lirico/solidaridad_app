from fastapi import APIRouter

from presentation.controllers import (
    auth_router,
    ping_router,
    products_router,
    terminals_router,
    transactions_router,
)


def create_router() -> APIRouter:
    router = APIRouter()

    router.include_router(ping_router)

    v1 = APIRouter(prefix="/v1")
    v1.include_router(auth_router, prefix="/auth", tags=["auth"])
    v1.include_router(products_router, prefix="/products", tags=["products"])
    v1.include_router(
        terminals_router,
        prefix="/terminals",
        tags=["terminals"],
    )
    v1.include_router(
        transactions_router,
        prefix="/transactions",
        tags=["transactions"],
    )

    router.include_router(v1)
    return router
