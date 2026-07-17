"""Product code helpers (DE49 is built directly from product_code)."""

from enum import StrEnum

from domain.exceptions import UnsupportedProduct


class ProductCode(StrEnum):
    CODE_993 = "993"
    CODE_994 = "994"
    CODE_995 = "995"
    CODE_996 = "996"
    CODE_997 = "997"


def product_code_de49(product_code: str) -> str:
    try:
        return ProductCode(product_code).value
    except ValueError as exc:
        raise UnsupportedProduct(product_code) from exc
