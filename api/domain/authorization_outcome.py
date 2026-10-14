"""Internal outcome of the original ISO authorization attempt."""

from enum import StrEnum


class AuthorizationOutcome(StrEnum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    NOT_SENT = "NOT_SENT"
    INDETERMINATE = "INDETERMINATE"
