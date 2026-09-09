"""Balance inquiry HTTP controller."""

from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.payments.check_balance import CheckBalance
from domain.exceptions import InvalidCardNumber, InvalidEntryMode, MissingTerminalId
from domain.money import AMOUNT_EXPONENT
from presentation.dependencies import (
    CurrentUser,
    get_check_balance,
    get_current_user,
)
from presentation.schemas.balance import (
    BalanceInquiryRequest,
    BalanceInquiryResponse,
    BalanceItemResponse,
)

router = APIRouter()


@router.post(
    "",
    status_code=status.HTTP_200_OK,
    response_model=BalanceInquiryResponse,
    responses={
        status.HTTP_400_BAD_REQUEST: {
            "description": "Validation / domain error",
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Missing/invalid token",
        },
    },
)
def check_balance(
    body: BalanceInquiryRequest,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    use_case: Annotated[CheckBalance, Depends(get_check_balance)],
) -> BalanceInquiryResponse | JSONResponse:
    try:
        result = use_case.execute(
            installation_id=current_user.installation_id,
            card_number=body.card_number,
            expiration_date=body.expiration_date,
            entry_mode=body.entry_mode,
            track2=body.track2,
        )
    except (InvalidCardNumber, InvalidEntryMode, MissingTerminalId) as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )

    items = [
        BalanceItemResponse(
            product=item.product,
            label=item.label,
            available_balance=str(
                Decimal(item.available_balance_minor) / (10**AMOUNT_EXPONENT)
            ),
        )
        for item in result.balances
    ]
    return BalanceInquiryResponse(
        status=result.status,
        user_message=result.user_message,
        balances=items,
    )
