"""Terminal provisioning HTTP request/response schemas."""

from typing import Annotated

from pydantic import BaseModel, Field
from pydantic.types import StringConstraints

LogicalDeviceId = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=128,
        pattern=r"^[A-Za-z0-9_-]+$",
    ),
]


class ResolveTerminalRequest(BaseModel):
    logical_device_id: LogicalDeviceId


class ResolveTerminalResponse(BaseModel):
    installation_id: str = Field(min_length=1, max_length=8)


class ErrorMessage(BaseModel):
    message: str
