"""Outbound ports for payment processing."""

from typing import Protocol

from domain.authorization import (
    AuthorizationResult,
    AuthorizeCommand,
    VoidCommand,
)
from domain.balance import BalanceCommand, BalanceResult


class IsoProcessor(Protocol):
    """Port: send an authorization/void/balance to the ISO processor (or mock)."""

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult: ...

    def void(self, command: VoidCommand) -> AuthorizationResult: ...

    def balance(self, command: BalanceCommand) -> BalanceResult: ...
