"""Mock ISO processor for local development without authkig."""

from domain.authorization import (
    AuthorizationResult,
    AuthorizationStatus,
    AuthorizeCommand,
    VoidCommand,
)
from domain.balance import BalanceCommand, BalanceResult
from domain.reversal import ReverseCommand, ReversalResult, ReversalStatus


class MockIsoProcessor:
    """Approves unless PAN is the known decline test card."""

    DECLINE_PAN = "4000000000000002"

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
        if command.card_number == self.DECLINE_PAN:
            return AuthorizationResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
                auth_id=None,
                retrieval_reference=None,
            )
        return AuthorizationResult(
            status=AuthorizationStatus.APPROVED,
            response_code="00",
            user_message="Aprobada",
            auth_id="MOCK01",
            retrieval_reference=command.stan.zfill(12),
        )

    def void(self, command: VoidCommand) -> AuthorizationResult:
        if command.card_number == self.DECLINE_PAN:
            return AuthorizationResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
                auth_id=None,
                retrieval_reference=None,
            )
        return AuthorizationResult(
            status=AuthorizationStatus.APPROVED,
            response_code="00",
            user_message="Aprobada",
            auth_id="MOCKVD",
            retrieval_reference=command.stan.zfill(12),
        )

    def reverse(self, command: ReverseCommand) -> ReversalResult:
        if command.card_number == self.DECLINE_PAN:
            return ReversalResult(
                status=ReversalStatus.PROCESSOR_DECLINED,
                response_code="05",
                user_message="Denegada",
            )
        # The current legacy 0410/00 cannot prove whether an original sale was
        # found and neutralized. The mock preserves that safe classification.
        return ReversalResult(
            status=ReversalStatus.INDETERMINATE,
            response_code="00",
            user_message="Resultado de reverso indeterminado",
        )

    def balance(self, command: BalanceCommand) -> BalanceResult:
        if command.card_number == self.DECLINE_PAN:
            return BalanceResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
            )
        return BalanceResult(
            status=AuthorizationStatus.APPROVED,
            response_code="00",
            user_message="Aprobada",
            available_balance_minor=100000,
            assigned_products=(
                "Tipo de asignacion: Garrafa 10 kg Garrafa 15 kg "
                "Garrafa 30 kg Tubo 45 kg Granel"
            ),
        )
