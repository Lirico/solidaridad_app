"""Technical reversal HTTP controller."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.payments.reverse_payment import ReversePayment
from domain.exceptions import (
    DomainError,
    InvalidAmount,
    InvalidCardNumber,
    InvalidStan,
    InvalidTerminalId,
    InvalidTicket,
    ProcessorUnavailable,
    ProcessorUnreachable,
    UnsupportedProduct,
)
from domain.reversal import ReversalResult, ReversalStatus, ReverseCommand
from presentation.dependencies import get_reverse_payment
from presentation.schemas.reversal import ReversalResponse, ReverseRequest

router = APIRouter()


def _response(result: ReversalResult) -> ReversalResponse:
    return ReversalResponse(
        status=result.status.value,
        response_code=result.response_code,
        user_message=result.user_message,
    )


def _failure_response(
    *,
    http_status: int,
    reversal_status: ReversalStatus,
    message: str,
) -> JSONResponse:
    return JSONResponse(
        status_code=http_status,
        content=ReversalResponse(
            status=reversal_status.value,
            response_code="96",
            user_message=message,
        ).model_dump(),
    )


@router.post(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ReversalResponse,
    responses={
        status.HTTP_400_BAD_REQUEST: {"description": "Validation / domain error"},
        status.HTTP_502_BAD_GATEWAY: {
            "model": ReversalResponse,
            "description": "Indeterminate reversal outcome",
        },
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "model": ReversalResponse,
            "description": "Processor unreachable; reversal was not sent",
        },
    },
)
def reverse(
    body: ReverseRequest,
    use_case: Annotated[ReversePayment, Depends(get_reverse_payment)],
) -> ReversalResponse | JSONResponse:
    command = ReverseCommand(
        product_code=body.product_code,
        amount_minor=body.amount_minor,
        card_number=body.card_number,
        expiration_date=body.expiration_date,
        terminal_id=body.terminal_id,
        original_stan=body.original_stan,
        original_ticket=body.original_ticket,
        reversal_stan=body.reversal_stan,
    )
    try:
        result = use_case.execute(command)
    except (
        InvalidAmount,
        InvalidCardNumber,
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
        return _failure_response(
            http_status=status.HTTP_503_SERVICE_UNAVAILABLE,
            reversal_status=ReversalStatus.NOT_SENT,
            message=str(exc),
        )
    except ProcessorUnavailable:
        return _failure_response(
            http_status=status.HTTP_502_BAD_GATEWAY,
            reversal_status=ReversalStatus.INDETERMINATE,
            message="Resultado del reverso indeterminado",
        )
    except DomainError as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )
    except Exception:
        return _failure_response(
            http_status=status.HTTP_502_BAD_GATEWAY,
            reversal_status=ReversalStatus.INDETERMINATE,
            message="Resultado del reverso indeterminado",
        )

    response = _response(result)
    if result.status == ReversalStatus.INDETERMINATE:
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content=response.model_dump(),
        )
    return response
