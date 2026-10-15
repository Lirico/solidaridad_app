"""Internal central-operator recovery review contracts."""

from datetime import datetime

from pydantic import BaseModel, Field

from domain.recovery_review import ManualRecoveryResolution


class ManualRecoveryResolutionRequest(BaseModel):
    resolution: ManualRecoveryResolution
    reason: str = Field(min_length=1, max_length=512)
    external_reference: str | None = Field(default=None, max_length=128)


class ManualRecoveryRetryRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=512)
    external_reference: str | None = Field(default=None, max_length=128)


class RecoveryAlertResponse(BaseModel):
    id: int
    cause: str
    state: str
    opened_at: datetime


class RecoveryReviewActionResponse(BaseModel):
    id: int
    operator_user_id: int
    action_type: str
    resolution: str | None
    reason: str
    external_reference: str | None
    created_at: datetime


class ManualRecoveryCaseResponse(BaseModel):
    job_id: int
    job_state: str
    result: str | None
    attempt_count: int
    last_error_code: str | None
    last_error_detail: str | None
    transaction_number: str
    terminal_id: str
    product: str
    amount: str
    card_last4: str
    transaction_status: str
    authorization_outcome: str | None
    created_at: datetime
    updated_at: datetime
    alerts: list[RecoveryAlertResponse]
    actions: list[RecoveryReviewActionResponse]


class ManualRecoveryCaseListResponse(BaseModel):
    items: list[ManualRecoveryCaseResponse]
