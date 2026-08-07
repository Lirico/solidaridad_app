"""Shared product catalog for Solidaridad services."""

from solidaridad_catalog.exceptions import UnknownProduct
from solidaridad_catalog.products import (
    ProcessorCode,
    Product,
    ProductInfo,
    ProductUnit,
    list_products,
    parse_processor_code,
    parse_product,
    processor_code,
)

__all__ = [
    "ProcessorCode",
    "Product",
    "ProductInfo",
    "ProductUnit",
    "UnknownProduct",
    "list_products",
    "parse_processor_code",
    "parse_product",
    "processor_code",
]
