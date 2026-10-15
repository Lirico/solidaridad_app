"""Validation helpers for values that may be emitted to operations."""

import re

_SAFE_PROCESSOR_CODE = re.compile(r"^[A-Za-z0-9_.:-]{1,64}$")
_CARD_NUMBER_SEQUENCE = re.compile(r"\d{12,}")


def sanitize_processor_code(value: str | None) -> str | None:
    """Keep bounded protocol codes and discard arbitrary gateway text."""
    if value is None:
        return None
    if (
        _SAFE_PROCESSOR_CODE.fullmatch(value)
        and not _CARD_NUMBER_SEQUENCE.search(value)
    ):
        return value
    return "UNSAFE_CODE"
