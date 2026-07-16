"""Currency helpers (ISO 4217 alpha → numeric for DE49)."""

from domain.exceptions import UnsupportedCurrency

# Numeric codes used in DE49 (ASCII, 3 chars).
_CURRENCY_NUMERIC: dict[str, str] = {
    "ARS": "032",
    "USD": "840",
}


def currency_numeric(currency: str) -> str:
    code = _CURRENCY_NUMERIC.get(currency.upper())
    if code is None:
        raise UnsupportedCurrency(currency)
    return code
