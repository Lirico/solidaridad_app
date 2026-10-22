"""Durable lifecycle for an attempted transaction void."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class VoidOperationOutcome(StrEnum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    NOT_SENT = "NOT_SENT"
    INDETERMINATE = "INDETERMINATE"


class VoidOperationStatus(StrEnum):
    PENDING = "PENDING"
    VOIDED = "VOIDED"
    DECLINED = "DECLINED"
    FAILED = "FAILED"
    UNDER_REVIEW = "UNDER_REVIEW"


@dataclass(frozen=True, slots=True)
class VoidOperation:
    id: int
    transaction_id: int
    idempotency_key: str
    request_fingerprint: str
    stan: str
    void_ticket: str
    original_ticket: str
    outcome: VoidOperationOutcome
    status: VoidOperationStatus
    processor_response_code: str | None
    user_message: str
    created_at: datetime
    updated_at: datetime
