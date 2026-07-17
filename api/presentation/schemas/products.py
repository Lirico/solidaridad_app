"""HTTP schemas for product catalog."""

from pydantic import BaseModel
from solidaridad_catalog import Product


class ProductResponse(BaseModel):
    code: Product
    label: str
