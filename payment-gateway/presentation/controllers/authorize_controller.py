"""Authorize HTTP controller."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.payments.authorize_payment import AuthorizePayment
from domain.authorization import AuthorizeCommand
from domain.exceptions import (
    DomainError,
    InvalidAmount,
    InvalidCardNumber,
    InvalidCvv,
    InvalidStan,
    InvalidTerminalId,
    InvalidTicket,
    ProcessorUnavailable,
    ProcessorUnreachable,
    UnsupportedProduct,
)
from presentation.dependencies import get_authorize_payment
from presentation.schemas.authorize import AuthorizeRequest, AuthorizeResponse

router = APIRouter()


@router.post(
    "",
    status_code=status.HTTP_200_OK,
    response_model=AuthorizeResponse,
    responses={
        status.HTTP_400_BAD_REQUEST: {
            "description": "Validation / domain error",
            "content": {
                "application/json": {
                    "example": {"message": "Número de tarjeta inválido"}
                }
            },
        },
        status.HTTP_502_BAD_GATEWAY: {
            "description": "Ambiguous processor failure (message may have arrived)",
            "content": {
                "application/json": {
                    "example": {"message": "Procesador de pagos no disponible"}
                }
            },
        },
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "description": "Processor unreachable (message never sent)",
            "content": {
                "application/json": {
                    "example": {
                        "message": "No se pudo conectar con el procesador de pagos"
                    }
                }
            },
        },
    },
)
def authorize(
    body: AuthorizeRequest,
    use_case: Annotated[AuthorizePayment, Depends(get_authorize_payment)],
) -> AuthorizeResponse | JSONResponse:
    command = AuthorizeCommand(
        product_code=body.product_code,
        amount_minor=body.amount_minor,
        card_number=body.card_number,
        terminal_id=body.terminal_id,
        stan=body.stan,
        ticket_number=body.ticket_number,
        expiration_date=body.expiration_date,
        entry_mode=body.entry_mode,
        track2=body.track2,
        cvv=body.cvv,
    )
    try:
        result = use_case.execute(command)
    except (
        InvalidAmount,
        InvalidCardNumber,
        InvalidCvv,
        InvalidStan,
        InvalidTerminalId,
        InvalidTicket,
        UnsupportedProduct,
    ) as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )
    except ProcessorUnreachable as exc:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"message": str(exc)},
        )
    except ProcessorUnavailable as exc:
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"message": str(exc)},
        )
    except DomainError as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )

    return AuthorizeResponse(
        status=result.status.value,
        response_code=result.response_code,
        user_message=result.user_message,
        auth_id=result.auth_id,
        retrieval_reference=result.retrieval_reference,
    )
