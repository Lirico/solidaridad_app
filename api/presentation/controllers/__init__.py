"""HTTP controllers (route handlers) package."""

from presentation.controllers.auth_controller import router as auth_router
from presentation.controllers.ping_controller import router as ping_router
from presentation.controllers.products_controller import router as products_router
from presentation.controllers.terminals_controller import router as terminals_router
from presentation.controllers.transactions_controller import (
    router as transactions_router,
)

__all__ = [
    "auth_router",
    "ping_router",
    "products_router",
    "terminals_router",
    "transactions_router",
]
