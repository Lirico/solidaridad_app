"""Internal endpoints for central review of ambiguous payment recovery."""

from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.payments.review_manual_recovery import (
    ManualRecoveryCase,
    ReviewManualRecovery,
)
from domain.exceptions import (
    ManualRecoveryCaseNotFound,
    ManualRecoveryConflict,
    ManualReversalRetryDisabled,
)
from domain.money import AMOUNT_EXPONENT
from presentation.dependencies import (
    CurrentUser,
    get_current_central_operator,
    get_review_manual_recovery,
)
from presentation.schemas.recovery import (
    ManualRecoveryCaseListResponse,
    ManualRecoveryCaseResponse,
    ManualRecoveryResolutionRequest,
    ManualRecoveryRetryRequest,
    RecoveryAlertResponse,
    RecoveryReviewActionResponse,
)

router = APIRouter()


@router.get("/jobs", response_model=ManualRecoveryCaseListResponse)
def list_manual_recovery_cases(
    _operator: Annotated[CurrentUser, Depends(get_current_central_operator)],
    use_case: Annotated[ReviewManualRecovery, Depends(get_review_manual_recovery)],
) -> ManualRecoveryCaseListResponse:
    return ManualRecoveryCaseListResponse(
        items=[_case_response(case) for case in use_case.list_cases()]
    )


@router.get("/jobs/{job_id}", response_model=ManualRecoveryCaseResponse)
def get_manual_recovery_case(
    job_id: int,
    _operator: Annotated[CurrentUser, Depends(get_current_central_operator)],
    use_case: Annotated[ReviewManualRecovery, Depends(get_review_manual_recovery)],
) -> ManualRecoveryCaseResponse | JSONResponse:
    try:
        return _case_response(use_case.get_case(job_id=job_id))
    except ManualRecoveryCaseNotFound as exc:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"message": str(exc)},
        )


@router.post("/jobs/{job_id}/resolve", response_model=ManualRecoveryCaseResponse)
def resolve_manual_recovery_case(
    job_id: int,
    body: ManualRecoveryResolutionRequest,
    operator: Annotated[CurrentUser, Depends(get_current_central_operator)],
    use_case: Annotated[ReviewManualRecovery, Depends(get_review_manual_recovery)],
) -> ManualRecoveryCaseResponse | JSONResponse:
    try:
        case = use_case.resolve(
            job_id=job_id,
            operator_user_id=operator.user_id,
            resolution=body.resolution,
            reason=body.reason,
            external_reference=body.external_reference,
        )
    except ManualRecoveryCaseNotFound as exc:
        return _error(status.HTTP_404_NOT_FOUND, exc)
    except ManualRecoveryConflict as exc:
        return _error(status.HTTP_409_CONFLICT, exc)
    return _case_response(case)


@router.post("/jobs/{job_id}/retry", response_model=ManualRecoveryCaseResponse)
def retry_manual_recovery_case(
    job_id: int,
    body: ManualRecoveryRetryRequest,
    operator: Annotated[CurrentUser, Depends(get_current_central_operator)],
    use_case: Annotated[ReviewManualRecovery, Depends(get_review_manual_recovery)],
) -> ManualRecoveryCaseResponse | JSONResponse:
    try:
        case = use_case.retry(
            job_id=job_id,
            operator_user_id=operator.user_id,
            reason=body.reason,
            external_reference=body.external_reference,
        )
    except ManualRecoveryCaseNotFound as exc:
        return _error(status.HTTP_404_NOT_FOUND, exc)
    except ManualRecoveryConflict as exc:
        return _error(status.HTTP_409_CONFLICT, exc)
    except ManualReversalRetryDisabled as exc:
        return _error(status.HTTP_409_CONFLICT, exc)
    return _case_response(case)


def _error(http_status: int, exc: Exception) -> JSONResponse:
    return JSONResponse(status_code=http_status, content={"message": str(exc)})


def _case_response(case: ManualRecoveryCase) -> ManualRecoveryCaseResponse:
    transaction = case.transaction
    job = case.job
    return ManualRecoveryCaseResponse(
        job_id=job.id,
        job_state=job.state.value,
        result=job.result,
        attempt_count=job.attempt_count,
        last_error_code=job.last_error_code,
        last_error_detail=job.last_error_detail_sanitized,
        transaction_number=transaction.transaction_number,
        terminal_id=transaction.terminal_id,
        product=transaction.product.value,
        amount=str(Decimal(transaction.amount_minor) / (10**AMOUNT_EXPONENT)),
        card_last4=transaction.card_last4,
        transaction_status=transaction.status.value,
        authorization_outcome=(
            transaction.authorization_outcome.value
            if transaction.authorization_outcome is not None
            else None
        ),
        created_at=transaction.created_at,
        updated_at=transaction.updated_at,
        alerts=[
            RecoveryAlertResponse(
                id=alert.id,
                cause=alert.cause,
                state=alert.state.value,
                opened_at=alert.opened_at,
            )
            for alert in case.alerts
        ],
        actions=[
            RecoveryReviewActionResponse(
                id=action.id,
                operator_user_id=action.operator_user_id,
                action_type=action.action_type.value,
                resolution=(
                    action.resolution.value if action.resolution is not None else None
                ),
                reason=action.reason,
                external_reference=action.external_reference,
                created_at=action.created_at,
            )
            for action in case.actions
        ],
    )
