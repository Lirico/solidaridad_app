"""Evidence-backed manual recovery decisions."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class ManualRecoveryResolution(StrEnum):
    REVERSED_CONFIRMED = "REVERSED_CONFIRMED"
    PROCESSOR_DECLINED = "PROCESSOR_DECLINED"
    ACTIVE_APPROVAL_CONFIRMED = "ACTIVE_APPROVAL_CONFIRMED"


class RecoveryReviewActionType(StrEnum):
    RESOLUTION = "RESOLUTION"
    MANUAL_RETRY = "MANUAL_RETRY"


@dataclass(frozen=True, slots=True)
class RecoveryReviewAction:
    id: int
    processor_job_id: int
    operator_user_id: int
    action_type: RecoveryReviewActionType
    resolution: ManualRecoveryResolution | None
    reason: str
    external_reference: str | None
    created_at: datetime
