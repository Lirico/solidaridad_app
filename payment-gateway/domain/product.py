"""Product code helpers (shared catalog → gateway domain errors)."""

from solidaridad_catalog import UnknownProduct
from solidaridad_catalog import parse_processor_code as _parse_processor_code

from domain.exceptions import UnsupportedProduct


def product_code_de49(product_code: str) -> str:
    try:
        return _parse_processor_code(product_code)
    except UnknownProduct as exc:
        raise UnsupportedProduct(product_code) from exc
