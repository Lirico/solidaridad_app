"""Auth HTTP controllers."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.auth.change_password import ChangePassword
from application.auth.login_rate_limit import LoginRateLimit
from application.auth.login_user import LoginUser
from application.auth.logout_user import LogoutUser
from domain.exceptions import (
    InvalidCredentials,
    InvalidCurrentPassword,
    MerchantNotConfigured,
    TooManyLoginAttempts,
    WeakPassword,
)
from presentation.dependencies import (
    CurrentUser,
    get_change_password,
    get_current_user,
    get_login_rate_limit,
    get_login_user,
    get_logout_user,
)
from presentation.schemas.auth import (
    ChangePasswordRequest,
    ChangePasswordResponse,
    LoginRequest,
    LoginTokenResponse,
    MerchantResponse,
    MessageResponse,
)

router = APIRouter()


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
        status.HTTP_429_TOO_MANY_REQUESTS: {
            "description": "Too many failed login attempts",
        },
    },
)
def login(
    body: LoginRequest,
    use_case: Annotated[LoginUser, Depends(get_login_user)],
    rate_limit: Annotated[LoginRateLimit, Depends(get_login_rate_limit)],
) -> LoginTokenResponse | JSONResponse:
    try:
        rate_limit.ensure_allowed(body.username)
        result = use_case.execute(
            username=body.username,
            password=body.password,
            installation_id=body.installation_id,
        )
    except TooManyLoginAttempts as exc:
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={"message": str(exc)},
        )
    except InvalidCredentials as exc:
        rate_limit.record_failure(body.username)
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"message": str(exc)},
        )
    except MerchantNotConfigured as exc:
        rate_limit.clear(body.username)
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"message": str(exc)},
        )
    rate_limit.clear(body.username)
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
    response_model=ChangePasswordResponse,
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
) -> ChangePasswordResponse | JSONResponse:
    try:
        token = use_case.execute(
            user_id=current_user.user_id,
            email=current_user.email,
            installation_id=current_user.installation_id,
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

    return ChangePasswordResponse(
        message="Contraseña actualizada correctamente",
        token=token,
    )


@router.post(
    "/logout",
    status_code=status.HTTP_200_OK,
    response_model=MessageResponse,
    responses={
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Missing or invalid token",
        },
    },
)
def logout(
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    use_case: Annotated[LogoutUser, Depends(get_logout_user)],
) -> MessageResponse | JSONResponse:
    try:
        use_case.execute(user_id=current_user.user_id)
    except InvalidCurrentPassword as exc:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"message": str(exc)},
        )
    return MessageResponse(message="Sesión cerrada")
