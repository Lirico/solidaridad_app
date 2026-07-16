"""Auth HTTP controllers."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.auth.login_user import LoginUser
from application.auth.register_user import RegisterUser
from domain.exceptions import (
    EmailAlreadyExists,
    InvalidCredentials,
    InvalidInstallationId,
    WeakPassword,
)
from presentation.dependencies import get_login_user, get_register_user
from presentation.schemas.auth import AuthTokenResponse, LoginRequest, RegisterRequest

router = APIRouter()


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=AuthTokenResponse,
    responses={
        status.HTTP_400_BAD_REQUEST: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "example": {
                        "message": (
                            "La contraseña debe tener al menos 8 caracteres"
                        )
                    }
                }
            },
        },
        status.HTTP_409_CONFLICT: {
            "description": "Email already registered",
            "content": {
                "application/json": {
                    "example": {"message": "El email ya está registrado"}
                }
            },
        },
    },
)
def register(
    body: RegisterRequest,
    use_case: Annotated[RegisterUser, Depends(get_register_user)],
) -> AuthTokenResponse | JSONResponse:
    try:
        result = use_case.execute(
            name=body.name,
            email=str(body.email),
            password=body.password,
            installation_id=body.installation_id,
        )
    except EmailAlreadyExists as exc:
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={"message": str(exc)},
        )
    except (WeakPassword, InvalidInstallationId) as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )

    return AuthTokenResponse(
        name=result.name,
        email=result.email,
        token=result.token,
        must_change_password=result.must_change_password,
    )


@router.post(
    "/login",
    status_code=status.HTTP_200_OK,
    response_model=AuthTokenResponse,
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
                "application/json": {
                    "example": {"message": "Credenciales inválidas"}
                }
            },
        },
    },
)
def login(
    body: LoginRequest,
    use_case: Annotated[LoginUser, Depends(get_login_user)],
) -> AuthTokenResponse | JSONResponse:
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
    except InvalidInstallationId as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )

    return AuthTokenResponse(
        name=result.name,
        email=result.email,
        token=result.token,
        must_change_password=result.must_change_password,
    )
