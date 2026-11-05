"""Merchant information presented to an authenticated terminal."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Merchant:
    code: str
    name: str
    address: str
    city: str
    tax_id: str
