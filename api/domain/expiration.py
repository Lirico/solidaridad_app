"""Card expiration (MMAA) shared by sale, void and balance."""

from domain.exceptions import InvalidExpirationDate


def parse_expiration_date(value: str | None) -> str | None:
    """Return MMAA or None. Empty input is allowed; anything else must be valid."""
    if value is None:
        return None
    exp = value.strip()
    if exp == "":
        return None
    if len(exp) != 4 or not exp.isdigit():
        raise InvalidExpirationDate()
    month = int(exp[:2])
    if month < 1 or month > 12:
        raise InvalidExpirationDate()
    return exp
