"""Products HTTP controller."""

from typing import Annotated

from fastapi import APIRouter, Depends, status

from domain.product import list_products
from presentation.dependencies import CurrentUser, require_operable_session
from presentation.schemas.products import ProductResponse

router = APIRouter()


@router.get(
    "",
    response_model=list[ProductResponse],
    summary="List supported products",
    responses={
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Missing/invalid token",
        },
    },
)
def get_products(
    _current_user: Annotated[CurrentUser, Depends(require_operable_session)],
) -> list[ProductResponse]:
    return [
        ProductResponse(code=item.code, label=item.label, unit=item.unit)
        for item in list_products(active_only=True)
    ]
