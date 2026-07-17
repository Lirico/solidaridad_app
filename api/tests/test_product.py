import pytest

from domain.exceptions import UnsupportedProduct
from domain.product import Product, parse_product, processor_product_code


def test_parse_product_ok() -> None:
    assert parse_product("garrafa_10") == Product.GARRAFA_10
    assert processor_product_code(Product.GARRAFA_10) == "993"


def test_parse_product_rejects_unknown() -> None:
    with pytest.raises(UnsupportedProduct):
        parse_product("ARS")
