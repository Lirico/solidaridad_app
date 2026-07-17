"""Canonical product catalog (API codes ↔ processor DE49 codes)."""

from dataclasses import dataclass
from enum import StrEnum

from solidaridad_catalog.exceptions import UnknownProduct


class Product(StrEnum):
    GARRAFA_10 = "GARRAFA_10"
    GARRAFA_15 = "GARRAFA_15"
    GARRAFA_30 = "GARRAFA_30"
    TUBO_45 = "TUBO_45"
    GRANEL = "GRANEL"


class ProcessorCode(StrEnum):
    CODE_993 = "993"
    CODE_994 = "994"
    CODE_995 = "995"
    CODE_996 = "996"
    CODE_997 = "997"


@dataclass(frozen=True, slots=True)
class ProductInfo:
    code: Product
    processor_code: ProcessorCode
    label: str
    active: bool = True


_CATALOG: tuple[ProductInfo, ...] = (
    ProductInfo(Product.GARRAFA_10, ProcessorCode.CODE_993, "Garrafa 10 kg"),
    ProductInfo(Product.GARRAFA_15, ProcessorCode.CODE_994, "Garrafa 15 kg"),
    ProductInfo(Product.GARRAFA_30, ProcessorCode.CODE_995, "Garrafa 30 kg"),
    ProductInfo(Product.TUBO_45, ProcessorCode.CODE_996, "Tubo 45 kg"),
    ProductInfo(Product.GRANEL, ProcessorCode.CODE_997, "Granel"),
)

_BY_PRODUCT: dict[Product, ProductInfo] = {item.code: item for item in _CATALOG}
_BY_PROCESSOR: dict[str, ProductInfo] = {
    item.processor_code.value: item for item in _CATALOG
}


def list_products(*, active_only: bool = True) -> tuple[ProductInfo, ...]:
    if not active_only:
        return _CATALOG
    return tuple(item for item in _CATALOG if item.active)


def parse_product(value: str) -> Product:
    try:
        return Product(value.strip().upper())
    except ValueError as exc:
        raise UnknownProduct(value) from exc


def processor_code(product: Product) -> str:
    return _BY_PRODUCT[product].processor_code.value


def parse_processor_code(value: str) -> str:
    code = value.strip()
    if code not in _BY_PROCESSOR:
        raise UnknownProduct(value)
    return code
