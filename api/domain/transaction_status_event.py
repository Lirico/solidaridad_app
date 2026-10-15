"""Transaction status history event types."""

from enum import StrEnum


class TransactionStatusEventType(StrEnum):
    CREATED = "CREATED"
    AUTHORIZATION_ATTEMPT = "AUTHORIZATION_ATTEMPT"
    GATEWAY_RESULT = "GATEWAY_RESULT"
    REVERSAL_ENQUEUED = "REVERSAL_ENQUEUED"
    VOID_RESULT = "VOID_RESULT"
    IDEMPOTENT_HIT = "IDEMPOTENT_HIT"


class TransactionStatusActorType(StrEnum):
    USER = "user"
    SYSTEM = "system"
