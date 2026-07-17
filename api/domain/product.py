"""Product catalog adapters (shared package → API domain errors)."""

from solidaridad_catalog import Product, UnknownProduct, list_products
from solidaridad_catalog import parse_product as _parse_product
from solidaridad_catalog import processor_code as _processor_code

from domain.exceptions import UnsupportedProduct

__all__ = [
    "Product",
    "list_products",
    "parse_product",
    "processor_product_code",
]


def parse_product(value: str) -> Product:
    try:
        return _parse_product(value)
    except UnknownProduct as exc:
        raise UnsupportedProduct(value) from exc


def processor_product_code(product: Product) -> str:
    return _processor_code(product)
