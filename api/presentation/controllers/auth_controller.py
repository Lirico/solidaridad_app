"""Auth HTTP controllers."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.auth.change_password import ChangePassword
from application.auth.login_user import LoginUser
from domain.exceptions import (
    InvalidCredentials,
    InvalidCurrentPassword,
    MerchantNotConfigured,
    WeakPassword,
)
from presentation.dependencies import (
    CurrentUser,
    get_change_password,
    get_current_user,
    get_login_user,
)
from presentation.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    LoginTokenResponse,
    MerchantResponse,
    MessageResponse,
    RegisterRequest,
)

router = APIRouter()


@router.post(
    "/register",
    status_code=status.HTTP_403_FORBIDDEN,
    responses={
        status.HTTP_403_FORBIDDEN: {"description": "Account provisioning is manual"},
    },
)
def register(body: RegisterRequest) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_403_FORBIDDEN,
        content={"message": "El alta de cuentas se realiza con un comercio asignado"},
    )


@router.post(
    "/login",
    status_code=status.HTTP_200_OK,
    response_model=LoginTokenResponse,
    responses={
        status.HTTP_400_BAD_REQUEST: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "example": {"message": "installation_id es requerido"}
                }
            },
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Invalid credentials",
            "content": {
                "application/json": {"example": {"message": "Credenciales inválidas"}}
            },
        },
        status.HTTP_403_FORBIDDEN: {
            "description": "Account has no merchant configured",
        },
    },
)
def login(
    body: LoginRequest,
    use_case: Annotated[LoginUser, Depends(get_login_user)],
) -> LoginTokenResponse | JSONResponse:
    try:
        result = use_case.execute(
            username=body.username,
            password=body.password,
            installation_id=body.installation_id,
        )
    except InvalidCredentials as exc:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"message": str(exc)},
        )
    except MerchantNotConfigured as exc:
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"message": str(exc)},
        )
    return LoginTokenResponse(
        name=result.name,
        email=result.email,
        token=result.token,
        must_change_password=result.must_change_password,
        merchant=MerchantResponse.model_validate(result.merchant, from_attributes=True),
    )


@router.post(
    "/change-password",
    status_code=status.HTTP_200_OK,
    response_model=MessageResponse,
    responses={
        status.HTTP_400_BAD_REQUEST: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "example": {
                        "message": ("La nueva contraseña debe ser distinta a la actual")
                    }
                }
            },
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Missing/invalid token or wrong current password",
            "content": {
                "application/json": {
                    "example": {"message": "Contraseña actual incorrecta"}
                }
            },
        },
    },
)
def change_password(
    body: ChangePasswordRequest,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    use_case: Annotated[ChangePassword, Depends(get_change_password)],
) -> MessageResponse | JSONResponse:
    try:
        use_case.execute(
            user_id=current_user.user_id,
            current_password=body.current_password,
            new_password=body.new_password,
        )
    except InvalidCurrentPassword as exc:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"message": str(exc)},
        )
    except WeakPassword as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )

    return MessageResponse(message="Contraseña actualizada correctamente")
