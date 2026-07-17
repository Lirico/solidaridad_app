"""Product catalog (API-facing codes → processor DE49 codes)."""

from enum import StrEnum

from domain.exceptions import UnsupportedProduct


class Product(StrEnum):
    GARRAFA_10 = "GARRAFA_10"
    GARRAFA_15 = "GARRAFA_15"
    GARRAFA_30 = "GARRAFA_30"
    TUBO_45 = "TUBO_45"
    GRANEL = "GRANEL"


_PRODUCT_TO_PROCESSOR: dict[Product, str] = {
    Product.GARRAFA_10: "993",
    Product.GARRAFA_15: "994",
    Product.GARRAFA_30: "995",
    Product.TUBO_45: "996",
    Product.GRANEL: "997",
}

AMOUNT_EXPONENT = 2


def parse_product(value: str) -> Product:
    try:
        return Product(value.strip().upper())
    except ValueError as exc:
        raise UnsupportedProduct(value) from exc


def processor_product_code(product: Product) -> str:
    return _PRODUCT_TO_PROCESSOR[product]
