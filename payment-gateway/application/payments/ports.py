"""Outbound ports for payment processing."""

from typing import Protocol

from domain.authorization import AuthorizationResult, AuthorizeCommand


class IsoProcessor(Protocol):
    """Port: send an authorization to the ISO processor (or mock)."""

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult: ...
