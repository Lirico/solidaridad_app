"""HTTP endpoints for the authenticated account."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from persistence.repositories.user_repository import UserRepository
from presentation.dependencies import CurrentUser, get_db, require_operable_session
from presentation.schemas.auth import CurrentMerchantResponse, MerchantResponse

router = APIRouter()


@router.get(
    "/merchant",
    response_model=CurrentMerchantResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: {"description": "Missing/invalid token"},
        status.HTTP_403_FORBIDDEN: {
            "description": "Account has no merchant configured",
        },
    },
)
def current_merchant(
    current_user: Annotated[CurrentUser, Depends(require_operable_session)],
    db: Annotated[Session, Depends(get_db)],
) -> CurrentMerchantResponse:
    merchant = UserRepository(db).get_merchant(current_user.user_id)
    if merchant is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La cuenta no tiene un comercio configurado",
        )
    return CurrentMerchantResponse(
        merchant=MerchantResponse.model_validate(merchant, from_attributes=True)
    )
