"""Transaction status history event types."""

from enum import StrEnum


class TransactionStatusEventType(StrEnum):
    CREATED = "CREATED"
    GATEWAY_RESULT = "GATEWAY_RESULT"
    VOID_RESULT = "VOID_RESULT"
    IDEMPOTENT_HIT = "IDEMPOTENT_HIT"


class TransactionStatusActorType(StrEnum):
    USER = "user"
    SYSTEM = "system"
