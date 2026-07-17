"""Transactions HTTP controller."""

from typing import Annotated

from fastapi import APIRouter, Depends, Header, status
from fastapi.responses import JSONResponse

from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
)
from domain.exceptions import (
    IdempotencyConflict,
    InvalidAmount,
    InvalidCardNumber,
    InvalidCvv,
    MissingIdempotencyKey,
    MissingTerminalId,
    TransactionNumberExhausted,
    UnsupportedProduct,
)
from presentation.dependencies import (
    CurrentUser,
    get_create_transaction,
    get_current_user,
)
from presentation.schemas.transactions import (
    CreateTransactionRequest,
    TransactionResponse,
)

router = APIRouter()


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=TransactionResponse,
    responses={
        status.HTTP_202_ACCEPTED: {
            "description": "Idempotent replay while still PENDING",
            "model": TransactionResponse,
        },
        status.HTTP_400_BAD_REQUEST: {
            "description": "Validation / domain error",
            "content": {
                "application/json": {
                    "example": {"message": "Número de tarjeta inválido"}
                }
            },
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Missing/invalid token",
            "content": {
                "application/json": {"example": {"message": "Autenticación requerida"}}
            },
        },
        status.HTTP_409_CONFLICT: {
            "description": "Idempotency key reused with different body",
            "content": {
                "application/json": {
                    "example": {"message": "Idempotency-Key ya usada con otro request"}
                }
            },
        },
    },
)
def create_transaction(
    body: CreateTransactionRequest,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    use_case: Annotated[CreateTransaction, Depends(get_create_transaction)],
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> TransactionResponse | JSONResponse:
    try:
        result = use_case.execute(
            user_id=current_user.user_id,
            installation_id=current_user.installation_id,
            idempotency_key=idempotency_key,
            product=body.product,
            amount=body.amount,
            card_number=body.card_number,
            cvv=body.cvv,
            expiration_date=body.expiration_date,
        )
    except (
        UnsupportedProduct,
        InvalidAmount,
        InvalidCardNumber,
        InvalidCvv,
        MissingIdempotencyKey,
        MissingTerminalId,
        TransactionNumberExhausted,
    ) as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )
    except IdempotencyConflict as exc:
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={"message": str(exc)},
        )

    payload = TransactionResponse(
        transaction_number=result.transaction.transaction_number,
        status=result.transaction.status.value,
        user_message=result.transaction.user_message or "",
        created_at=result.transaction.created_at,
    )
    if result.http_status == CreateTransactionHttpStatus.ACCEPTED:
        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content=payload.model_dump(mode="json"),
        )
    return payload
