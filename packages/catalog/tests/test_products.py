import pytest

from solidaridad_catalog import (
    Product,
    UnknownProduct,
    list_products,
    parse_processor_code,
    parse_product,
    processor_code,
)


def test_list_products_returns_active_catalog() -> None:
    products = list_products()
    assert len(products) == 5
    assert products[0].code == Product.GARRAFA_10
    assert products[0].processor_code == "993"
    assert products[0].label == "Garrafa 10 kg"
    assert products[0].unit.singular == "unidad"
    assert products[0].unit.plural == "unidades"
    assert products[-1].unit.singular == "m3"
    assert products[-1].unit.plural == "m3"


def test_parse_product_and_processor_code() -> None:
    assert parse_product("garrafa_10") == Product.GARRAFA_10
    assert processor_code(Product.GARRAFA_10) == "993"
    assert parse_processor_code("993") == "993"


def test_rejects_unknown_codes() -> None:
    with pytest.raises(UnknownProduct):
        parse_product("ARS")
    with pytest.raises(UnknownProduct):
        parse_processor_code("998")
