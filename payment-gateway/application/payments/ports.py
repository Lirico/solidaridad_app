"""Outbound ports for payment processing."""

from typing import Protocol

from domain.authorization import (
    AuthorizationResult,
    AuthorizeCommand,
    VoidCommand,
)


class IsoProcessor(Protocol):
    """Port: send an authorization/void to the ISO processor (or mock)."""

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult: ...

    def void(self, command: VoidCommand) -> AuthorizationResult: ...
