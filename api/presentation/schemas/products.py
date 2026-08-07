"""HTTP schemas for product catalog."""

from pydantic import BaseModel
from solidaridad_catalog import Product, ProductUnit


class ProductResponse(BaseModel):
    code: Product
    label: str
    unit: ProductUnit
