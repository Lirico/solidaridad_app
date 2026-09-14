from fastapi import APIRouter

from presentation.controllers import (
    auth_router,
    balance_router,
    ping_router,
    products_router,
    transactions_router,
)


def create_router() -> APIRouter:
    router = APIRouter()
    router.include_router(ping_router)

    v1 = APIRouter(prefix="/v1")
    v1.include_router(auth_router, prefix="/auth", tags=["auth"])
    v1.include_router(products_router, prefix="/products", tags=["products"])
    v1.include_router(
        transactions_router,
        prefix="/transactions",
        tags=["transactions"],
    )
    v1.include_router(balance_router, prefix="/balance", tags=["balance"])
    router.include_router(v1)
    return router
