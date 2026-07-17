"""Products HTTP controller."""

from fastapi import APIRouter

from domain.product import list_products
from presentation.schemas.products import ProductResponse

router = APIRouter()


@router.get(
    "",
    response_model=list[ProductResponse],
    summary="List supported products",
)
def get_products() -> list[ProductResponse]:
    return [
        ProductResponse(code=item.code, label=item.label)
        for item in list_products(active_only=True)
    ]
