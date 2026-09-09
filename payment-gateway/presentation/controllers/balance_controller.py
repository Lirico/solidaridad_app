"""Balance inquiry HTTP controller."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.payments.check_balance import CheckBalance
from domain.balance import BalanceCommand
from domain.exceptions import (
    DomainError,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    ProcessorUnavailable,
    ProcessorUnreachable,
    UnsupportedProduct,
)
from presentation.dependencies import get_check_balance
from presentation.schemas.authorize import BalanceRequest, BalanceResponse

router = APIRouter()


@router.post(
    "",
    status_code=status.HTTP_200_OK,
    response_model=BalanceResponse,
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
def balance(
    body: BalanceRequest,
    use_case: Annotated[CheckBalance, Depends(get_check_balance)],
) -> BalanceResponse | JSONResponse:
    command = BalanceCommand(
        product_code=body.product_code,
        card_number=body.card_number,
        terminal_id=body.terminal_id,
        stan=body.stan,
        expiration_date=body.expiration_date,
        entry_mode=body.entry_mode,
        track2=body.track2,
    )
    try:
        result = use_case.execute(command)
    except (
        InvalidCardNumber,
        InvalidStan,
        InvalidTerminalId,
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

    return BalanceResponse(
        status=result.status.value,
        response_code=result.response_code,
        user_message=result.user_message,
        available_balance_minor=result.available_balance_minor,
        assigned_products=result.assigned_products,
    )
