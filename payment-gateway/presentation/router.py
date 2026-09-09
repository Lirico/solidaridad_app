from fastapi import APIRouter

from presentation.controllers import (
    authorize_router,
    balance_router,
    ping_router,
    void_router,
)


def create_router() -> APIRouter:
    router = APIRouter()
    router.include_router(ping_router)

    v1 = APIRouter(prefix="/v1")
    v1.include_router(authorize_router, prefix="/authorize", tags=["authorize"])
    v1.include_router(void_router, prefix="/void", tags=["void"])
    v1.include_router(balance_router, prefix="/balance", tags=["balance"])
    router.include_router(v1)
    return router
