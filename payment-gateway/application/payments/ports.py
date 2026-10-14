"""Outbound ports for payment processing."""

from typing import Protocol

from domain.authorization import (
    AuthorizationResult,
    AuthorizeCommand,
    VoidCommand,
)
from domain.balance import BalanceCommand, BalanceResult
from domain.reversal import ReversalResult, ReverseCommand


class IsoProcessor(Protocol):
    """Port: send a payment operation to the ISO processor (or mock)."""

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult: ...

    def void(self, command: VoidCommand) -> AuthorizationResult: ...

    def reverse(self, command: ReverseCommand) -> ReversalResult: ...

    def balance(self, command: BalanceCommand) -> BalanceResult: ...
