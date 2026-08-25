"""Terminal provisioning HTTP controllers."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from application.terminals.resolve_terminal import ResolveTerminal
from domain.exceptions import TerminalNotProvisioned
from presentation.dependencies import get_resolve_terminal
from presentation.schemas.terminals import (
    ErrorMessage,
    ResolveTerminalRequest,
    ResolveTerminalResponse,
)

router = APIRouter()


@router.post(
    "/resolve",
    status_code=status.HTTP_200_OK,
    response_model=ResolveTerminalResponse,
    responses={
        status.HTTP_404_NOT_FOUND: {
            "description": "Terminal not provisioned",
            "content": {
                "application/json": {
                    "example": {"message": "La terminal no está provisionada"}
                }
            },
        },
        status.HTTP_422_UNPROCESSABLE_ENTITY: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "example": {
                        "detail": [
                            {
                                "loc": ["body", "logical_device_id"],
                                "msg": "Invalid format",
                                "type": "value_error",
                            }
                        ]
                    }
                }
            },
        },
    },
)
def resolve_terminal(
    body: ResolveTerminalRequest,
    use_case: Annotated[ResolveTerminal, Depends(get_resolve_terminal)],
) -> ResolveTerminalResponse | JSONResponse:
    try:
        result = use_case.execute(logical_device_id=body.logical_device_id)
    except TerminalNotProvisioned as exc:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content=ErrorMessage(message=str(exc)).model_dump(),
        )
    return ResolveTerminalResponse(installation_id=result.installation_id)
