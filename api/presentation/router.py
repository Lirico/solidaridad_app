from fastapi import APIRouter

from presentation.controllers import ping_router


def create_router() -> APIRouter:
    router = APIRouter()
    router.include_router(ping_router)
    return router
