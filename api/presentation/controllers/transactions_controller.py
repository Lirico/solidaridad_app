"""Transactions HTTP controller."""

from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, Header, Query, status
from fastapi.responses import JSONResponse

from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
)
from application.payments.list_transactions import ListTransactions
from domain.exceptions import (
    IdempotencyConflict,
    InvalidAmount,
    InvalidCardNumber,
    InvalidCvv,
    MissingIdempotencyKey,
    MissingTerminalId,
    UnsupportedProduct,
)
from domain.money import AMOUNT_EXPONENT
from presentation.dependencies import (
    CurrentUser,
    get_create_transaction,
    get_current_user,
    get_list_transactions,
)
from presentation.schemas.transactions import (
    CreateTransactionRequest,
    TransactionItemResponse,
    TransactionListResponse,
    TransactionResponse,
)

router = APIRouter()


@router.get(
    "",
    response_model=TransactionListResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Missing/invalid token",
        },
    },
)
def list_transactions(
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    use_case: Annotated[ListTransactions, Depends(get_list_transactions)],
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> TransactionListResponse:
    result = use_case.execute(
        terminal_id=current_user.installation_id,
        limit=limit,
        offset=offset,
    )
    items = [
        TransactionItemResponse(
            transaction_number=t.transaction_number,
            product=t.product.value,
            amount=str(Decimal(t.amount_minor) / (10**AMOUNT_EXPONENT)),
            card_last4=t.card_last4,
            status=t.status.value,
            user_message=t.user_message or "",
            created_at=t.created_at,
        )
        for t in result.transactions
    ]
    return TransactionListResponse(items=items, total=result.total)


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