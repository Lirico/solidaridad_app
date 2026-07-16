from fastapi import APIRouter

from presentation.controllers import authorize_router, ping_router


def create_router() -> APIRouter:
    router = APIRouter()
    router.include_router(ping_router)

    v1 = APIRouter(prefix="/v1")
    v1.include_router(authorize_router, prefix="/authorize", tags=["authorize"])
    router.include_router(v1)
    return router
