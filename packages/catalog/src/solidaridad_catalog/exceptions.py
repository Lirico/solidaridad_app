"""Catalog-level errors."""


class UnknownProduct(ValueError):
    """Raised when a product or processor code is not in the catalog."""

    def __init__(self, value: str = "") -> None:
        self.value = value
        super().__init__(f"Unknown product: {value}" if value else "Unknown product")
