"""Internal provisioning endpoint for central recovery operators."""

from typing import Annotated

from fastapi import APIRouter, Depends, Header, status
from fastapi.responses import JSONResponse

from application.auth.provision_central_operator import ProvisionCentralOperator
from domain.exceptions import (
    CentralOperatorProvisioningForbidden,
    EmailAlreadyExists,
    WeakPassword,
)
from domain.user import UserRole
from presentation.dependencies import get_provision_central_operator
from presentation.schemas.auth import (
    CentralOperatorProvisionRequest,
    CentralOperatorProvisionResponse,
)

router = APIRouter()


@router.post(
    "/operators",
    status_code=status.HTTP_201_CREATED,
    response_model=CentralOperatorProvisionResponse,
)
def provision_central_operator(
    body: CentralOperatorProvisionRequest,
    use_case: Annotated[
        ProvisionCentralOperator,
        Depends(get_provision_central_operator),
    ],
    provisioning_token: Annotated[
        str | None,
        Header(alias="X-Central-Provisioning-Token"),
    ] = None,
) -> CentralOperatorProvisionResponse | JSONResponse:
    try:
        result = use_case.execute(
            provisioning_token=provisioning_token,
            name=body.name,
            email=str(body.email),
            password=body.password,
        )
    except CentralOperatorProvisioningForbidden as exc:
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"message": str(exc)},
        )
    except EmailAlreadyExists as exc:
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={"message": str(exc)},
        )
    except WeakPassword as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"message": str(exc)},
        )

    return CentralOperatorProvisionResponse(
        name=result.name,
        email=result.email,
        role=UserRole.CENTRAL_OPERATOR.value,
    )
